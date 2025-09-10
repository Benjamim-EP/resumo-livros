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
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:septima_biblia/services/notification_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:septima_biblia/services/tutorial_service.dart'; // <<< ARQUIVO REFATORADO
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

  // --- LÓGICA DO TUTORIAL AGORA É GERENCIADA PELO SERVIÇO ---
  final TutorialService _tutorialService = TutorialService();
  bool _tutorialHasBeenChecked = false; // Flag de controle de execução
  final UpdateService _updateService = UpdateService();

  StreamSubscription? _userProgressSubscription; // <<< ADICIONE ESTA LINHA
  int _previousCompletionCount = 0; // <<< ADICIONE ESTA LINHA
  StreamSubscription? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _setupUserListener();
    //_updateService.checkForUpdate();

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

    // Pega os dados necessários do estado
    int targetIndexFromAction =
        storeInstance.state.userState.targetBottomNavIndex ?? -1;
    final bool isGuest = storeInstance.state.userState.isGuestUser;

    // Variável para o índice final
    int finalIndex;

    // --- INÍCIO DA LÓGICA HIERÁRQUICA CORRIGIDA ---

    // 1. Prioridade Máxima: Verificar se é um convidado.
    //    A regra do convidado sobrescreve qualquer outra coisa.
    if (isGuest) {
      // Para o convidado, usamos a ação se ela existir (ex: vindo da StartScreen),
      // caso contrário, o padrão é SEMPRE 2 (Bíblia).
      finalIndex = (targetIndexFromAction != -1) ? targetIndexFromAction : 2;
      finalIndex = 2;
      print(
          "DEBUG: Modo CONVIDADO detectado. Índice final: $finalIndex (Ação: $targetIndexFromAction, Padrão: 2)");
    }
    // 2. Se NÃO for convidado, então verificamos as ações ou usamos o padrão para usuários logados.
    else if (targetIndexFromAction != -1) {
      // Usuário logado com uma ação de navegação específica.
      finalIndex = targetIndexFromAction;
      print("DEBUG: Usuário LOGADO com AÇÃO. Índice final: $finalIndex");
    } else {
      // Usuário logado sem nenhuma ação, vai para o perfil.
      finalIndex = 0;
      print(
          "DEBUG: Usuário LOGADO com REGRA PADRÃO. Índice final: $finalIndex");
    }

    // --- FIM DA LÓGICA HIERÁRQUICA CORRIGIDA ---

    // 3. Validação final de segurança (sem alterações)
    if (finalIndex < 0 || finalIndex >= _pages.length) {
      finalIndex = isGuest ? 2 : 0;
    }

    // 4. Aplica o estado à UI (sem alterações)
    if (finalIndex != _selectedIndex) {
      setState(() => _selectedIndex = finalIndex);
    }

    // 5. Limpa a ação do Redux para que ela não seja usada novamente (sem alterações)
    if (targetIndexFromAction != -1) {
      storeInstance.dispatch(ClearTargetBottomNavAction());
    }

    // Carrega o status premium inicial (sem alterações)
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
      // O builder nos dá um contexto que está "dentro" do ShowCaseWidget.
      // Isso é essencial para que ShowCaseWidget.of() funcione.
      builder: (showcaseContext) {
        // Usamos um StatefulWidget para controlar a flag e evitar loops.
        // A lógica de verificação é movida para dentro do builder,
        // onde temos acesso tanto ao contexto correto quanto ao estado do Redux.
        final storeInstance =
            StoreProvider.of<AppState>(context, listen: false);
        final isGuest = storeInstance.state.userState.isGuestUser;
        final isLoggedIn = storeInstance.state.userState.isLoggedIn;

        // Se for a primeira vez que este build é executado E o usuário está logado (não é convidado)
        if (!_tutorialHasBeenChecked &&
            isLoggedIn &&
            !isGuest &&
            !kIsIntegrationTest) {
          // Marca como verificado para não rodar de novo
          _tutorialHasBeenChecked = true;

          // Chama o serviço do tutorial com o contexto correto
          _tutorialService.startMainTutorial(showcaseContext);
        }

        // Finalmente, retorna o Scaffold, que é a UI principal da tela.
        return _buildScaffold();
      },
      autoPlay: false,
      blurValue: 2,
    );
  }

  Widget _buildScaffold() {
    final storeInstance = StoreProvider.of<AppState>(context, listen: false);
    final ThemeData currentThemeData = Theme.of(context);

    return StoreConnector<AppState, _MainAppScreenViewModel>(
      converter: (store) => _MainAppScreenViewModel.fromStore(store),
      onDidChange: (previousViewModel, newViewModel) {
        // O onDidChange agora SÓ atualiza o status premium da UI,
        // ele não mexe mais na navegação.
        if (mounted && newViewModel != null) {
          _updatePremiumUI(newViewModel.isPremium);
        }
      },
      builder: (context, mainScreenViewModel) {
        final l10n = AppLocalizations.of(context)!;
        if (mainScreenViewModel == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
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
                    // ✅ Se for convidado, o botão do drawer é nulo
                    leading: isGuest
                        ? null
                        : Builder(
                            builder: (BuildContext context) {
                              return IconButton(
                                icon:
                                    const ProfileActionButton(avatarRadius: 20),
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                                tooltip: 'Abrir Menu',
                              );
                            },
                          ),

                    // Agora o título pode ser apenas um texto simples.
                    title: Text(_getAppBarTitle(_selectedIndex, context)),
                    // As actions (botões da direita) permanecem as mesmas.
                    actions: [
                      _tutorialService.buildShowcase(
                        key: _tutorialService.keyMudarTema,
                        title: l10n.showcaseChangeThemeTitle,
                        description: l10n
                            .showcaseChangeThemeDesc, // Corrigido de "Description" para "Desc"
                        child: IconButton(
                          icon:
                              Icon(_getThemeIcon(currentThemeOptionFromRedux)),
                          tooltip: 'Mudar Tema',
                          onPressed: () {
                            final nextTheme =
                                _getNextTheme(currentThemeOptionFromRedux);
                            storeInstance.dispatch(SetThemeAction(nextTheme));
                          },
                        ),
                      ),
                      _tutorialService.buildShowcase(
                        key: _tutorialService.keyMoedas,
                        title: 'Suas Moedas',
                        description:
                            'Use moedas para buscas avançadas. Assista a um anúncio para ganhar mais!',
                        child: StoreConnector<AppState, _UserCoinsViewModel>(
                          converter: (store) =>
                              _UserCoinsViewModel.fromStore(store),
                          builder: (context, coinsViewModel) {
                            // Se o usuário for premium, não mostra nada
                            if (coinsViewModel.isPremium) {
                              return const SizedBox.shrink();
                            }

                            // Constrói a UI das moedas para usuários não-premium
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Ícone dinâmico: Presente para recompensa, Moeda para o normal
                                  Icon(
                                    coinsViewModel.hasWeeklyReward
                                        ? Icons.card_giftcard
                                        : Icons.monetization_on,
                                    color: currentThemeData.colorScheme.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 4),
                                  // Exibe o total de moedas calculado
                                  Text(
                                    '${coinsViewModel.totalUserCoins}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: currentThemeData.appBarTheme
                                              .titleTextStyle?.color ??
                                          currentThemeData
                                              .colorScheme.onPrimary,
                                    ),
                                  ),
                                  // Lógica para mostrar o botão de ganhar moedas ou o ícone de "cheio"
                                  if (coinsViewModel.totalUserCoins <
                                      MAX_COINS_LIMIT)
                                    // Se ainda não atingiu o limite, mostra o timer/botão para ganhar mais
                                    const RewardCooldownTimer()
                                  else
                                    // Se atingiu o limite, mostra o ícone de check
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: currentThemeData
                                            .colorScheme.primary
                                            .withOpacity(0.7),
                                        size: 22,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      _tutorialService.buildShowcase(
                        key: _tutorialService.keySejaPremium,
                        title: 'Seja Premium',
                        description:
                            'Toque aqui para desbloquear todos os recursos e remover os anúncios.',
                        child: StoreConnector<AppState, bool>(
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
                      if (!mounted) return;
                      if (storeInstance.state.userState.isGuestUser &&
                          index == 0) {
                        showLoginRequiredDialog(context,
                            featureName: "seu perfil");
                        return;
                      }
                      int previousIndex = _selectedIndex;
                      if (previousIndex != index) {
                        final String tabName = _getAppBarTitle(index, context);
                        AnalyticsService.instance.logTabSelected(tabName);
                        print(
                            "Analytics: Evento 'main_tab_selected' registrado para a aba: '$tabName'");
                        final bool isPremium =
                            _UserCoinsViewModel.fromStore(storeInstance)
                                .isPremium;
                        void navigateToNewTab() {
                          if (mounted) {
                            setState(() => _selectedIndex = index);
                            if (previousIndex == 1 && index != 1) {
                              final userState = storeInstance.state.userState;
                              if (userState.userId != null) {
                                if (userState.pendingSectionsToAdd.isNotEmpty ||
                                    userState
                                        .pendingSectionsToRemove.isNotEmpty) {
                                  storeInstance.dispatch(
                                      ProcessPendingBibleProgressAction());
                                }
                              }
                            }
                          }
                        }

                        // CÓDIGO NOVO E CORRETO
                        if (!isPremium) {
                          interstitialManager
                              .tryShowInterstitial(
                                  fromScreen:
                                      "MainAppScreen_TabChange_From_${_getAppBarTitle(previousIndex, context)}_To_${_getAppBarTitle(index, context)}") // <<< MUDANÇA AQUI
                              .then((_) {
                            navigateToNewTab();
                          });
                        } else {
                          navigateToNewTab();
                        }
                      }
                    },
                    items: [
                      _tutorialService.buildShowcasedBottomNavItem(
                          key: _tutorialService.keyAbaUsuario,
                          icon: Icons.account_circle,
                          label: l10n.navUser, // <-- MUDANÇA
                          description: l10n.showcaseUserDesc), // <-- MUDANÇA
                      BottomNavigationBarItem(
                        icon: Image.asset(
                          'assets/icon/bibtok.png',
                          width: 24,
                          height: 24,
                          color: _selectedIndex == 1 ? null : Colors.grey[600],
                          colorBlendMode: BlendMode.modulate,
                        ),
                        label: 'BibTok', // Mantido, pois é uma marca
                      ),
                      _tutorialService.buildShowcasedBottomNavItem(
                          key: _tutorialService.keyAbaBiblia,
                          icon: Icons.book_outlined,
                          label: l10n.bible, // <-- MUDANÇA
                          description: l10n.showcaseBibleDesc), // <-- MUDANÇA
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.groups_outlined),
                        label: l10n.community, // <-- MUDANÇA
                      ),
                      _tutorialService.buildShowcasedBottomNavItem(
                          key: _tutorialService.keyAbaBiblioteca,
                          icon: Icons.local_library_outlined,
                          label: l10n.library, // <-- MUDANÇA
                          description: l10n.showcaseLibraryDesc), // <-- MUDANÇA
                    ],
                  ),
          ),
        );
      },
    );
  }
}
