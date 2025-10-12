// lib/components/bottomNavigationBar/bottomNavigationBar.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/buttons/animated_infinity_icon.dart';
import 'package:septima_biblia/components/buttons/animated_premium_button.dart';
import 'package:septima_biblia/components/buttons/reward_cooldown_timer.dart';
import 'package:septima_biblia/components/drawer/app_drawer.dart';
import 'package:septima_biblia/components/login_required.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/pages/bible_page.dart';
import 'package:septima_biblia/pages/bibtok_page.dart';
import 'package:septima_biblia/pages/community/community_page.dart';
import 'package:septima_biblia/pages/library_page.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/pages/query_results_page.dart';
import 'package:septima_biblia/pages/user_page.dart';
import 'package:septima_biblia/pages/user_page/profile_action_button.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/middleware/ad_middleware.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:septima_biblia/services/notification_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:septima_biblia/services/update_service.dart'; // <<< ARQUIVO REFATORADO

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// ViewModels (sem alterações)
class _UserCoinsViewModel {
  // ✅ ALTERAÇÃO: O ViewModel agora retorna o total calculado
  final int totalUserCoins;
  final bool hasWeeklyReward;
  final bool isPremium;

  _UserCoinsViewModel({
    required this.totalUserCoins,
    required this.hasWeeklyReward,
    required this.isPremium,
  });

  static _UserCoinsViewModel fromStore(Store<AppState> store) {
    // --- 1. LÓGICA ROBUSTA PARA DETERMINAR O STATUS PREMIUM ---
    bool premiumStatus = false;
    final userDetails = store.state.userState.userDetails ?? {};

    // Primeiro, verifica os dados do Firestore
    final status = userDetails['subscriptionStatus'] as String?;
    final endDateTimestamp = userDetails['subscriptionEndDate'] as Timestamp?;

    if (status == 'active') {
      if (endDateTimestamp != null) {
        premiumStatus = endDateTimestamp.toDate().isAfter(DateTime.now());
      } else {
        // Considera premium se o status for ativo mas não houver data de fim (caso raro)
        premiumStatus = true;
      }
    }

    // Como fallback, verifica o estado da assinatura no Redux
    // (útil logo após uma compra, antes do listener do Firestore atualizar)
    if (!premiumStatus) {
      premiumStatus = store.state.subscriptionState.status ==
          SubscriptionStatus.premiumActive;
    }

    // --- 2. LÓGICA PARA CALCULAR O TOTAL DE MOEDAS ---
    int mainCoins = store.state.userState.userCoins;
    int rewardCoins = userDetails['weeklyRewardCoins'] as int? ?? 0;
    final rewardExpiration =
        (userDetails['rewardExpiration'] as Timestamp?)?.toDate();

    bool hasValidReward = false;
    int totalCoinsToShow = mainCoins;

    // Verifica se a recompensa é válida
    if (rewardExpiration != null && rewardExpiration.isAfter(DateTime.now())) {
      // Se a data de expiração ainda não passou...
      if (rewardCoins > 0) {
        // ...e se há moedas de recompensa para usar...
        hasValidReward = true;
        // ...o total a ser exibido para o usuário é a soma das duas.
        totalCoinsToShow += rewardCoins;
      }
    }

    // --- 3. RETORNA O VIEWMODEL COM OS DADOS CALCULADOS ---
    return _UserCoinsViewModel(
      totalUserCoins: totalCoinsToShow, // Usa o total calculado
      hasWeeklyReward:
          hasValidReward, // Informa a UI se há uma recompensa ativa
      isPremium: premiumStatus,
    );
  }
}

class _MainAppScreenViewModel {
  final Map<String, dynamic>? userDetails;
  final int? targetBottomNavIndex;
  final bool isPremium;
  final AppThemeOption activeThemeOption;
  final bool isFocusMode;

  _MainAppScreenViewModel({
    this.userDetails,
    this.targetBottomNavIndex,
    required this.isPremium,
    required this.activeThemeOption,
    required this.isFocusMode,
  });

  static _MainAppScreenViewModel fromStore(Store<AppState> store) {
    bool premiumStatus = false;
    final userDetails = store.state.userState.userDetails;
    if (userDetails != null) {
      final status = userDetails['subscriptionStatus'] as String?;
      final endDateTimestamp = userDetails['subscriptionEndDate'] as Timestamp?;
      if (status == 'active') {
        if (endDateTimestamp != null) {
          premiumStatus = endDateTimestamp.toDate().isAfter(DateTime.now());
        } else {
          premiumStatus = true;
        }
      }
    }
    if (!premiumStatus) {
      premiumStatus = store.state.subscriptionState.status ==
          SubscriptionStatus.premiumActive;
    }

    return _MainAppScreenViewModel(
      userDetails: userDetails,
      targetBottomNavIndex: store.state.userState.targetBottomNavIndex,
      isPremium: premiumStatus,
      activeThemeOption: store.state.themeState.activeThemeOption,
      isFocusMode: store.state.userState.isFocusMode,
    );
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});
  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;
  final GlobalKey<NavigatorState> _userNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _bibleNavigatorKey =
      GlobalKey<NavigatorState>();
  late final List<Widget> _pages;
  StreamSubscription? _userDocSubscription;
  bool _isPremiumFromState = false;
  static bool _notificationsInitialized = false;
  bool _tutorialHasBeenChecked = false;
  final UpdateService _updateService = UpdateService();
  StreamSubscription? _userProgressSubscription;
  int _previousCompletionCount = 0;
  StreamSubscription? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _setupUserListener();
    if (!_notificationsInitialized) {
      _scheduleNotifications();
      _notificationsInitialized = true;
    }

    _pages = [
      _buildTabNavigator(_userNavigatorKey, const UserPage()),
      const BibTokPage(),
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()),
      const CommunityPage(),
      const LibraryPage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeScreenState();
        _updateService.checkForUpdate(context);
      }
    });
  }

  void _initializeScreenState() {
    final storeInstance = StoreProvider.of<AppState>(context, listen: false);
    final isGuest = storeInstance.state.userState.isGuestUser;

    // Ação de navegação tem prioridade, se existir.
    int targetIndex = storeInstance.state.userState.targetBottomNavIndex ?? -1;

    if (targetIndex != -1) {
      setState(() => _selectedIndex = targetIndex);
      storeInstance.dispatch(ClearTargetBottomNavAction());
    } else {
      // Se não houver ação, aplica a regra padrão.
      setState(() => _selectedIndex = isGuest ? 2 : 0);
    }

    final initialViewModel = _UserCoinsViewModel.fromStore(storeInstance);
    _updatePremiumUI(initialViewModel.isPremium);
  }

  Future<void> _scheduleNotifications() async {
    try {
      final NotificationService notificationService = NotificationService();
      await notificationService.init();
      await notificationService.scheduleDailyDevotionals();
    } catch (e) {
      print("MainAppScreen: Erro ao agendar notificações: $e");
    }
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    _userProgressSubscription?.cancel();
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  void _setupUserListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final storeInstance = store;
      _userDocSubscription?.cancel();
      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null && mounted) {
          final userData = snapshot.data() as Map<String, dynamic>;
          storeInstance.dispatch(UserDetailsLoadedAction(userData));
          final currentViewModel = _UserCoinsViewModel.fromStore(storeInstance);
          _updatePremiumUI(currentViewModel.isPremium);
        }
      });
      _userProgressSubscription?.cancel();
      _userProgressSubscription = FirebaseFirestore.instance
          .collection('userBibleProgress')
          .doc(userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null && mounted) {
          final progressData = snapshot.data() as Map<String, dynamic>;
          final newCompletionCount =
              progressData['bibleCompletionCount'] as int? ?? 0;

          // Se o contador aumentou E era zero antes, significa que foi a primeira conclusão!
          if (newCompletionCount > _previousCompletionCount &&
              _previousCompletionCount == 0) {
            print(
                "MainAppScreen Listener: Detectada a primeira conclusão da Bíblia!");

            // >>> INÍCIO DA CORREÇÃO <<<
            // DE: final installTimestamp = store.state.userState.userDetails?['dataCadastro'] as Timestamp?;
            // PARA:
            final dynamic installTimestampRaw =
                store.state.userState.userDetails?['dataCadastro'];
            final DateTime? installDate = (installTimestampRaw is Timestamp)
                ? installTimestampRaw.toDate()
                : null;
            // >>> FIM DA CORREÇÃO <<<

            int daysSinceInstall = 0;
            if (installDate != null) {
              daysSinceInstall = DateTime.now().difference(installDate).inDays;
            }

            AnalyticsService.instance.logEvent(
              name: 'user_engagement_milestone',
              parameters: {
                'milestone_name': 'completed_first_book',
                'days_since_install': daysSinceInstall,
              },
            );
            print(
                "Analytics: Marco 'completed_first_book' registrado pelo cliente.");
          }

          // Atualiza a contagem anterior para a próxima verificação
          _previousCompletionCount = newCompletionCount;
        }
      });
      _notificationsSubscription?.cancel();
      _notificationsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false) // Ouve apenas as não lidas
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          final count = snapshot.docs.length;
          print("Listener de Notificações: $count não lidas.");
          storeInstance.dispatch(UnreadNotificationsCountUpdatedAction(count));
        }
      });
    }
  }

  void _updatePremiumUI(bool isNowPremium) {
    if (mounted && isNowPremium != _isPremiumFromState) {
      setState(() => _isPremiumFromState = isNowPremium);
    }
  }

  Future<void> _showLearningGoalDialog(BuildContext context) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    final theme = Theme.of(context);

    // Controlador para o campo de texto, inicializado com o valor atual
    final TextEditingController controller = TextEditingController(
      text: store.state.userState.learningGoal ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text("Seu Foco de Estudo",
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Descreva o que você busca aprender. A IA usará essa informação para destacar versículos relevantes para você.",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Ex: "Quero entender mais sobre a graça de Deus."',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () {
                final newGoal = controller.text.trim();
                // Despacha a ação para atualizar o estado e salvar no Firestore
                store.dispatch(UpdateLearningGoalAction(newGoal));
                Navigator.of(dialogContext).pop();
                // Mostra um feedback de sucesso
                CustomNotificationService.showSuccess(
                    context, 'Foco de estudo salvo!');
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabNavigator(
      GlobalKey<NavigatorState>? navigatorKey, Widget child) {
    if (navigatorKey == null) return child;
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
            builder: (settings.name == '/queryResults')
                ? (_) => const QueryResultsPage()
                : (_) => child,
            settings: settings);
      },
    );
  }

  // ... (outros métodos auxiliares: _onWillPop, _getAppBarTitle, etc. sem alterações)
  Future<bool> _onWillPop() async {
    final currentKey = _currentNavigatorKey;
    if (currentKey == null ||
        currentKey.currentState == null ||
        !currentKey.currentState!.canPop()) {
      return true;
    }
    currentKey.currentState!.pop();
    return false;
  }

  GlobalKey<NavigatorState>? get _currentNavigatorKey {
    switch (_selectedIndex) {
      case 0:
        return _userNavigatorKey;
      case 1:
        return _bibleNavigatorKey;
      default:
        return null;
    }
  }

  String _getAppBarTitle(int index, BuildContext context) {
    switch (index) {
      case 0:
        return AppLocalizations.of(context)!.profile;
      case 1:
        return "BibTok"; // Mantém se for uma marca
      case 2:
        return AppLocalizations.of(context)!.bible;
      case 3:
        return AppLocalizations.of(context)!.community;
      case 4:
        return AppLocalizations.of(context)!.library;
      default:
        return "Septima";
    }
  }

  int _calculateActualIndexFromTarget(int targetIndexFromAction) {
    return (targetIndexFromAction >= 0 && targetIndexFromAction < _pages.length)
        ? targetIndexFromAction
        : 0;
  }

  AppThemeOption _getNextTheme(AppThemeOption currentTheme) {
    final themes = AppThemeOption.values;
    final currentIndex = themes.indexOf(currentTheme);
    final nextIndex = (currentIndex + 1) % themes.length;
    return themes[nextIndex];
  }

  IconData _getThemeIcon(AppThemeOption currentTheme) {
    switch (currentTheme) {
      case AppThemeOption.green:
        return Icons.eco_outlined;
      case AppThemeOption.septimaDark:
        return Icons.nightlight_round;
      case AppThemeOption.septimaLight:
        return Icons.wb_sunny_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (showcaseContext) {
        final storeInstance =
            StoreProvider.of<AppState>(context, listen: false);
        final isGuest = storeInstance.state.userState.isGuestUser;
        final isLoggedIn = storeInstance.state.userState.isLoggedIn;

        if (!_tutorialHasBeenChecked &&
            isLoggedIn &&
            !isGuest &&
            !kIsIntegrationTest) {
          _tutorialHasBeenChecked = true;
        }

        // ✅ O StoreConnector agora envolve o Scaffold para ouvir as mudanças de navegação
        return StoreConnector<AppState, _MainAppScreenViewModel>(
          converter: (store) => _MainAppScreenViewModel.fromStore(store),
          // ✅ onDidChange é o lugar correto para reagir a mudanças de estado que afetam a UI
          onDidChange: (previousViewModel, newViewModel) {
            if (newViewModel == null) return;

            // Reage à mudança de status premium
            if (previousViewModel?.isPremium != newViewModel.isPremium) {
              _updatePremiumUI(newViewModel.isPremium);
            }

            // ✅ LÓGICA DE NAVEGAÇÃO CORRIGIDA
            // Se o targetBottomNavIndex mudou e não é nulo, atualiza a aba selecionada
            if (newViewModel.targetBottomNavIndex != null &&
                newViewModel.targetBottomNavIndex != _selectedIndex) {
              if (mounted) {
                setState(() {
                  _selectedIndex = newViewModel.targetBottomNavIndex!;
                });
                // Limpa a ação do Redux para que ela não seja reativada
                storeInstance.dispatch(ClearTargetBottomNavAction());
              }
            }
          },
          builder: (context, mainScreenViewModel) {
            // O resto do seu método _buildScaffold agora pode ser chamado aqui diretamente
            return _buildScaffold(mainScreenViewModel);
          },
        );
      },
      autoPlay: false,
      blurValue: 2,
    );
  }

  Widget _buildScaffold(_MainAppScreenViewModel? mainScreenViewModel) {
    final storeInstance = StoreProvider.of<AppState>(context, listen: false);
    final ThemeData currentThemeData = Theme.of(context);

    final l10n = AppLocalizations.of(context)!;
    if (mainScreenViewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final AppThemeOption currentThemeOptionFromRedux =
        mainScreenViewModel.activeThemeOption;

    final bool isGuest = storeInstance.state.userState.isGuestUser;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        drawer: isGuest ? null : const AppDrawer(),
        appBar: mainScreenViewModel.isFocusMode
            ? null
            : AppBar(
                leading: isGuest
                    ? null
                    : Builder(
                        builder: (BuildContext context) {
                          return IconButton(
                            icon: const ProfileActionButton(avatarRadius: 20),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            tooltip: 'Abrir Menu',
                          );
                        },
                      ),
                title: Text(_getAppBarTitle(_selectedIndex, context)),
                actions: [
                  // --- Botão de Tema (sem showcase) ---
                  IconButton(
                    icon: Icon(_getThemeIcon(currentThemeOptionFromRedux)),
                    tooltip: 'Mudar Tema',
                    onPressed: () {
                      final nextTheme =
                          _getNextTheme(currentThemeOptionFromRedux);
                      storeInstance.dispatch(SetThemeAction(nextTheme));
                    },
                  ),

                  // --- Botão de Foco de Estudo (sem showcase) ---
                  if (!isGuest)
                    IconButton(
                      icon: const Icon(Icons.track_changes_outlined),
                      tooltip: 'Definir Foco de Estudo',
                      onPressed: () => _showLearningGoalDialog(context),
                    ),

                  // --- Widget de Moedas (sem showcase) ---
                  StoreConnector<AppState, _UserCoinsViewModel>(
                    converter: (store) => _UserCoinsViewModel.fromStore(store),
                    builder: (context, coinsViewModel) {
                      if (coinsViewModel.isPremium) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              coinsViewModel.hasWeeklyReward
                                  ? Icons.card_giftcard
                                  : Icons.monetization_on,
                              color: currentThemeData.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${coinsViewModel.totalUserCoins}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: currentThemeData
                                        .appBarTheme.titleTextStyle?.color ??
                                    currentThemeData.colorScheme.onPrimary,
                              ),
                            ),
                            if (coinsViewModel.totalUserCoins < MAX_COINS_LIMIT)
                              const RewardCooldownTimer()
                            else
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.check_circle,
                                  color: currentThemeData.colorScheme.primary
                                      .withOpacity(0.7),
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  // --- Widget Premium (sem showcase) ---
                  StoreConnector<AppState, bool>(
                    converter: (store) =>
                        _UserCoinsViewModel.fromStore(store).isPremium,
                    builder: (context, isPremium) {
                      if (isPremium) {
                        return const Padding(
                          padding: EdgeInsets.only(right: 12.0),
                          child: AnimatedInfinityIcon(),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: AnimatedPremiumButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SubscriptionSelectionPage(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: mainScreenViewModel.isFocusMode
            ? null
            : BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _selectedIndex,
                onTap: (index) {
                  // ... (sua lógica onTap permanece a mesma)
                  if (!mounted) return;
                  if (storeInstance.state.userState.isGuestUser && index == 0) {
                    showLoginRequiredDialog(context, featureName: "seu perfil");
                    return;
                  }
                  int previousIndex = _selectedIndex;
                  if (previousIndex != index) {
                    final String tabName = _getAppBarTitle(index, context);
                    AnalyticsService.instance.logTabSelected(tabName);

                    final bool isPremium =
                        _UserCoinsViewModel.fromStore(storeInstance).isPremium;
                    void navigateToNewTab() {
                      if (mounted) {
                        setState(() => _selectedIndex = index);
                        if (previousIndex == 1 && index != 1) {
                          final userState = storeInstance.state.userState;
                          if (userState.userId != null) {
                            if (userState.pendingSectionsToAdd.isNotEmpty ||
                                userState.pendingSectionsToRemove.isNotEmpty) {
                              storeInstance.dispatch(
                                  ProcessPendingBibleProgressAction());
                            }
                          }
                        }
                      }
                    }

                    if (!isPremium) {
                      interstitialManager
                          .tryShowInterstitial(
                              fromScreen:
                                  "MainAppScreen_TabChange_From_${_getAppBarTitle(previousIndex, context)}_To_${_getAppBarTitle(index, context)}")
                          .then((_) {
                        navigateToNewTab();
                      });
                    } else {
                      navigateToNewTab();
                    }
                  }
                },
                items: [
                  // --- Itens da BottomNav (sem showcase) ---
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.account_circle),
                    label: l10n.navUser,
                  ),
                  BottomNavigationBarItem(
                    icon: Image.asset(
                      'assets/icon/bibtok.png',
                      width: 24,
                      height: 24,
                      color: _selectedIndex == 1 ? null : Colors.grey[600],
                      colorBlendMode: BlendMode.modulate,
                    ),
                    label: 'BibTok',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.book_outlined),
                    label: l10n.bible,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.groups_outlined),
                    label: l10n.community,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.local_library_outlined),
                    label: l10n.library,
                  ),
                ],
              ),
      ),
    );
  }
}
