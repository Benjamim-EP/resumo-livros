// lib/components/bottomNavigationBar/bottomNavigationBar.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/login_required.dart';
import 'package:septima_biblia/pages/bible_page.dart';
import 'package:septima_biblia/pages/devotional_page/devotional_diary_page.dart';
import 'package:septima_biblia/pages/library_page.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/pages/query_results_page.dart';
import 'package:septima_biblia/pages/user_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/middleware/ad_middleware.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:septima_biblia/services/notification_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:septima_biblia/services/tutorial_service.dart'; // <<< ARQUIVO REFATORADO

// ViewModels (sem alterações)
class _UserCoinsViewModel {
  final int userCoins;
  final bool isPremium;

  _UserCoinsViewModel({required this.userCoins, required this.isPremium});

  static _UserCoinsViewModel fromStore(Store<AppState> store) {
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
    return _UserCoinsViewModel(
      userCoins: store.state.userState.userCoins,
      isPremium: premiumStatus,
    );
  }
}

class _MainAppScreenViewModel {
  final Map<String, dynamic>? userDetails;
  final int? targetBottomNavIndex;
  final bool isPremium;
  final AppThemeOption activeThemeOption;

  _MainAppScreenViewModel({
    this.userDetails,
    this.targetBottomNavIndex,
    required this.isPremium,
    required this.activeThemeOption,
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
    return _MainAppScreenViewModel(
      userDetails: userDetails,
      targetBottomNavIndex: store.state.userState.targetBottomNavIndex,
      isPremium: premiumStatus,
      activeThemeOption: store.state.themeState.activeThemeOption,
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
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()),
      const LibraryPage(),
      const DevotionalDiaryPage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeScreenState();
      }
    });
  }

  void _initializeScreenState() {
    final storeInstance = StoreProvider.of<AppState>(context, listen: false);
    int initialTargetIndexFromRedux =
        storeInstance.state.userState.targetBottomNavIndex ?? -1;
    final bool isGuest = storeInstance.state.userState.isGuestUser;
    int newInitialIndex = 0;
    if (isGuest) {
      newInitialIndex =
          (initialTargetIndexFromRedux != -1) ? initialTargetIndexFromRedux : 1;
    } else if (initialTargetIndexFromRedux != -1) {
      newInitialIndex = initialTargetIndexFromRedux;
    }
    if (newInitialIndex < 0 || newInitialIndex >= _pages.length) {
      newInitialIndex = isGuest ? 1 : 0;
    }
    if (newInitialIndex != _selectedIndex) {
      setState(() => _selectedIndex = newInitialIndex);
    }
    if (initialTargetIndexFromRedux != -1) {
      storeInstance.dispatch(ClearTargetBottomNavAction());
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

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return "Meu Perfil";
      case 1:
        return "Bíblia";
      case 2:
        return "Biblioteca";
      case 3:
        return "Diário";
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
        if (!_tutorialHasBeenChecked && isLoggedIn && !isGuest) {
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
        if (mounted &&
            newViewModel != null &&
            previousViewModel != newViewModel) {
          _updatePremiumUI(newViewModel.isPremium);
          if (newViewModel.targetBottomNavIndex != null) {
            int targetIndex = newViewModel.targetBottomNavIndex!;
            int actualNewIndex = _calculateActualIndexFromTarget(targetIndex);
            if (actualNewIndex != _selectedIndex) {
              setState(() => _selectedIndex = actualNewIndex);
            }
            storeInstance.dispatch(ClearTargetBottomNavAction());
          }
        }
      },
      builder: (context, mainScreenViewModel) {
        if (mainScreenViewModel == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final AppThemeOption currentThemeOptionFromRedux =
            mainScreenViewModel.activeThemeOption;

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            appBar: AppBar(
              title: Text(_getAppBarTitle(_selectedIndex)),
              actions: [
                _tutorialService.buildShowcase(
                  key: _tutorialService.keyMudarTema,
                  title: 'Mudar Tema',
                  description:
                      'Toque aqui para alternar entre os temas de cores do aplicativo.',
                  child: IconButton(
                    icon: Icon(_getThemeIcon(currentThemeOptionFromRedux)),
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
                    converter: (store) => _UserCoinsViewModel.fromStore(store),
                    builder: (context, coinsViewModel) {
                      if (coinsViewModel.isPremium)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on,
                                color: currentThemeData.colorScheme.primary,
                                size: 22),
                            const SizedBox(width: 4),
                            Text('${coinsViewModel.userCoins}',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: currentThemeData.appBarTheme
                                            .titleTextStyle?.color ??
                                        currentThemeData
                                            .colorScheme.onPrimary)),
                            if (coinsViewModel.userCoins < MAX_COINS_LIMIT)
                              IconButton(
                                icon: Icon(Icons.add_circle_outline,
                                    color: currentThemeData.colorScheme.primary,
                                    size: 24),
                                tooltip: 'Ganhar Moedas',
                                onPressed: () => storeInstance
                                    .dispatch(RequestRewardedAdAction()),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.check_circle,
                                    color: currentThemeData.colorScheme.primary
                                        .withOpacity(0.7),
                                    size: 22),
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
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.verified_user_outlined,
                              color: Colors.amber),
                        );
                      }
                      return IconButton(
                        icon: const Icon(Icons.workspace_premium_outlined),
                        tooltip: 'Torne-se Premium',
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const SubscriptionSelectionPage())),
                      );
                    },
                  ),
                ),
              ],
            ),
            body: IndexedStack(index: _selectedIndex, children: _pages),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (index) {
                if (!mounted) return;
                if (storeInstance.state.userState.isGuestUser && index == 0) {
                  showLoginRequiredDialog(context, featureName: "seu perfil");
                  return;
                }
                int previousIndex = _selectedIndex;
                if (previousIndex != index) {
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
                            storeInstance
                                .dispatch(ProcessPendingBibleProgressAction());
                          }
                        }
                      }
                    }
                  }

                  if (!isPremium) {
                    interstitialManager
                        .tryShowInterstitial(
                            fromScreen:
                                "MainAppScreen_TabChange_From_${_getAppBarTitle(previousIndex)}_To_${_getAppBarTitle(index)}")
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
                    label: 'Usuário',
                    description: 'Acesse seu perfil, progresso e notas aqui.'),
                _tutorialService.buildShowcasedBottomNavItem(
                    key: _tutorialService.keyAbaBiblia,
                    icon: Icons.book_outlined,
                    label: 'Bíblia',
                    description:
                        'Navegue pelos livros da Bíblia e faça estudos profundos.'),
                _tutorialService.buildShowcasedBottomNavItem(
                    key: _tutorialService.keyAbaBiblioteca,
                    icon: Icons.local_library_outlined,
                    label: 'Biblioteca',
                    description:
                        'Explore uma vasta coleção de sermões, livros e outros recursos.'),
                _tutorialService.buildShowcasedBottomNavItem(
                    key: _tutorialService.keyAbaDiario,
                    icon: Icons.edit_note_outlined,
                    label: 'Diário',
                    description:
                        'Registre suas reflexões diárias, orações e promessas.'),
              ],
            ),
          ),
        );
      },
    );
  }
}
