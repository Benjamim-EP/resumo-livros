// lib/components/bottomNavigationBar/bottomNavigationBar.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/login_required.dart'; // Importação que estava faltando na sua versão original
import 'package:septima_biblia/pages/bible_page.dart';
import 'package:septima_biblia/pages/devotional_page/devotional_diary_page.dart';
import 'package:septima_biblia/pages/library_page.dart';
import 'package:septima_biblia/pages/query_results_page.dart';
import 'package:septima_biblia/pages/user_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/middleware/ad_middleware.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/ad_helper.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
// >>> INÍCIO DO NOVO IMPORT <<<
import 'package:septima_biblia/services/notification_service.dart';
// >>> FIM DO NOVO IMPORT <<<

// ViewModel para o StoreConnector das moedas (como antes)
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserCoinsViewModel &&
          runtimeType == other.runtimeType &&
          userCoins == other.userCoins &&
          isPremium == other.isPremium;

  @override
  int get hashCode => userCoins.hashCode ^ isPremium.hashCode;
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

  // >>> INÍCIO DA NOVA VARIÁVEL DE CONTROLE <<<
  // Garante que o agendamento só aconteça uma vez por sessão.
  static bool _notificationsInitialized = false;
  // >>> FIM DA NOVA VARIÁVEL DE CONTROLE <<<

  @override
  void initState() {
    super.initState();
    _setupUserListener();

    // >>> INÍCIO DO NOVO BLOCO DE CÓDIGO <<<
    // Agenda as notificações aqui, de forma segura, apenas uma vez.
    if (!_notificationsInitialized) {
      _scheduleNotifications();
      _notificationsInitialized = true;
    }
    // >>> FIM DO NOVO BLOCO DE CÓDIGO <<<

    _pages = [
      _buildTabNavigator(_userNavigatorKey, const UserPage()),
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()),
      const LibraryPage(),
      const DevotionalDiaryPage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storeInstance =
            StoreProvider.of<AppState>(context, listen: false);

        int initialTargetIndexFromRedux =
            storeInstance.state.userState.targetBottomNavIndex ?? -1;
        final bool isGuest = storeInstance.state.userState.isGuestUser;

        int newInitialIndex = 0;

        if (isGuest) {
          newInitialIndex = (initialTargetIndexFromRedux != -1)
              ? initialTargetIndexFromRedux
              : 1;
        } else if (initialTargetIndexFromRedux != -1) {
          newInitialIndex = initialTargetIndexFromRedux;
        }

        if (newInitialIndex < 0 || newInitialIndex >= _pages.length) {
          newInitialIndex = isGuest ? 1 : 0;
        }

        if (newInitialIndex != _selectedIndex) {
          setState(() {
            _selectedIndex = newInitialIndex;
          });
        }

        if (initialTargetIndexFromRedux != -1) {
          storeInstance.dispatch(ClearTargetBottomNavAction());
        }

        final initialViewModel = _UserCoinsViewModel.fromStore(storeInstance);
        _updatePremiumUI(initialViewModel.isPremium);
      }
    });
  }

  // >>> INÍCIO DA NOVA FUNÇÃO <<<
  /// Agenda as notificações diárias de forma segura.
  Future<void> _scheduleNotifications() async {
    try {
      print("MainAppScreen: Tentando agendar notificações...");
      final NotificationService notificationService = NotificationService();
      await notificationService.init(); // Inicializa o serviço
      await notificationService
          .scheduleDailyDevotionals(); // Agenda as notificações
      print("MainAppScreen: Notificações agendadas com sucesso.");
    } catch (e) {
      print("MainAppScreen: Erro ao agendar notificações: $e");
      // Não trava o app, apenas loga o erro.
    }
  }
  // >>> FIM DA NOVA FUNÇÃO <<<

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
          .listen((DocumentSnapshot snapshot) {
        if (snapshot.exists && snapshot.data() != null && mounted) {
          final userData = snapshot.data() as Map<String, dynamic>;
          final Timestamp? endDateTimestamp =
              userData['subscriptionEndDate'] as Timestamp?;
          final DateTime? endDateDateTime = endDateTimestamp?.toDate();

          storeInstance.dispatch(SubscriptionStatusUpdatedAction(
            status: userData['subscriptionStatus'] ?? 'inactive',
            endDate: endDateDateTime,
            subscriptionId: userData['stripeSubscriptionId'] as String?,
            customerId: userData['stripeCustomerId'] as String?,
            priceId: userData['activePriceId'] as String?,
          ));
          storeInstance.dispatch(UserDetailsLoadedAction(userData));

          final currentViewModel = _UserCoinsViewModel.fromStore(storeInstance);
          _updatePremiumUI(currentViewModel.isPremium);
        }
      });
    }
  }

  void _updatePremiumUI(bool isNowPremium) {
    if (!mounted) return;
    if (isNowPremium != _isPremiumFromState) {
      setState(() {
        _isPremiumFromState = isNowPremium;
      });
    }
  }

  Widget _buildTabNavigator(
      GlobalKey<NavigatorState>? navigatorKey, Widget child) {
    if (navigatorKey == null) {
      return child;
    }
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        WidgetBuilder? builder;
        if (settings.name == '/queryResults') {
          builder = (_) => const QueryResultsPage();
        }
        builder ??= (_) => child;
        return MaterialPageRoute(builder: builder, settings: settings);
      },
    );
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
    if (targetIndexFromAction >= 0 && targetIndexFromAction < _pages.length) {
      return targetIndexFromAction;
    }
    return 0;
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
    final storeInstance = StoreProvider.of<AppState>(context, listen: false);
    final ThemeData currentThemeData = Theme.of(context);

    return StoreConnector<AppState, _MainAppScreenViewModel>(
      converter: (store) => _MainAppScreenViewModel.fromStore(store),
      onDidChange: (previousViewModel, newViewModel) {
        if (!mounted) return;
        if (newViewModel != null && previousViewModel != newViewModel) {
          _updatePremiumUI(newViewModel.isPremium);

          if (newViewModel.targetBottomNavIndex != null) {
            int targetIndex = newViewModel.targetBottomNavIndex!;
            int actualNewIndex = _calculateActualIndexFromTarget(targetIndex);

            if (actualNewIndex != _selectedIndex) {
              setState(() {
                _selectedIndex = actualNewIndex;
              });
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
                IconButton(
                  icon: Icon(_getThemeIcon(currentThemeOptionFromRedux)),
                  tooltip: 'Mudar Tema',
                  onPressed: () {
                    final nextTheme =
                        _getNextTheme(currentThemeOptionFromRedux);
                    storeInstance.dispatch(SetThemeAction(nextTheme));
                  },
                ),
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
                            Icons.monetization_on,
                            color: currentThemeData.colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${coinsViewModel.userCoins}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: currentThemeData
                                      .appBarTheme.titleTextStyle?.color ??
                                  currentThemeData.colorScheme.onPrimary,
                            ),
                          ),
                          if (coinsViewModel.userCoins < MAX_COINS_LIMIT)
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: currentThemeData.colorScheme.primary,
                                size: 24,
                              ),
                              tooltip: 'Ganhar Moedas',
                              onPressed: () {
                                storeInstance
                                    .dispatch(RequestRewardedAdAction());
                              },
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
              ],
            ),
            body: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    if (mounted) {
                      if (storeInstance.state.userState.isGuestUser &&
                          index == 0) {
                        showLoginRequiredDialog(context,
                            featureName: "seu perfil");
                        return;
                      }

                      int previousIndex = _selectedIndex;

                      if (previousIndex != index) {
                        interstitialManager
                            .tryShowInterstitial(
                                fromScreen:
                                    "MainAppScreen_TabChange_From_${_getAppBarTitle(previousIndex)}_To_${_getAppBarTitle(index)}")
                            .then((_) {
                          if (mounted) {
                            setState(() {
                              _selectedIndex = index;
                            });

                            if (previousIndex == 1 && index != 1) {
                              final userState = storeInstance.state.userState;
                              if (userState.userId != null) {
                                final pendingToAdd =
                                    userState.pendingSectionsToAdd;
                                final pendingToRemove =
                                    userState.pendingSectionsToRemove;
                                if (pendingToAdd.isNotEmpty ||
                                    pendingToRemove.isNotEmpty) {
                                  storeInstance.dispatch(
                                      ProcessPendingBibleProgressAction());
                                }
                              }
                            }
                          }
                        });
                      } else {
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
                    }
                  },
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.account_circle), label: 'Usuário'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.book_outlined), label: 'Bíblia'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.local_library_outlined),
                        label: 'Biblioteca'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.edit_note_outlined), label: 'Diário'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MainAppScreenViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userDetails, other.userDetails) &&
          targetBottomNavIndex == other.targetBottomNavIndex &&
          isPremium == other.isPremium &&
          activeThemeOption == other.activeThemeOption;

  @override
  int get hashCode =>
      userDetails.hashCode ^
      targetBottomNavIndex.hashCode ^
      isPremium.hashCode ^
      activeThemeOption.hashCode;
}
