// lib/components/bottomNavigationBar/bottomNavigationBar.dart

import 'package:flutter/foundation.dart'; // Para mapEquals em _MainAppScreenViewModel
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/bible_page.dart';
import 'package:septima_biblia/pages/library_page.dart';
import 'package:septima_biblia/pages/query_results_page.dart';
import 'package:septima_biblia/pages/user_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/middleware/ad_middleware.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/ad_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/services/interstitial_manager.dart'; // Para AppThemeOption

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

// Widget placeholder (como antes)
class _UnderConstructionPlaceholder extends StatelessWidget {
  final String pageTitle;
  const _UnderConstructionPlaceholder({super.key, required this.pageTitle});

  @override
  Widget build(BuildContext context) {
    // ... (implementação como antes)
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction,
                size: 80, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 20),
            Text(
              'A seção "$pageTitle" está em construção!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Volte em breve para novidades.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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

  @override
  void initState() {
    super.initState();
    _setupUserListener();

    _pages = [
      _buildTabNavigator(_userNavigatorKey, const UserPage()),
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()),
      const LibraryPage(),
      //const _UnderConstructionPlaceholder(pageTitle: "Chat IA"),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storeInstance =
            StoreProvider.of<AppState>(context, listen: false);

        // >>> INÍCIO DA MODIFICAÇÃO <<<
        int initialTargetIndexFromRedux =
            storeInstance.state.userState.targetBottomNavIndex ??
                -1; // -1 se nulo
        final bool isGuest = storeInstance.state.userState.isGuestUser;

        int newInitialIndex = 0; // Padrão é a UserPage (índice 0)

        if (isGuest) {
          // Se for convidado, e não houver uma navegação específica solicitada pelo Redux,
          // vai para a BiblePage (índice 1).
          // Se houver uma navegação específica (ex: vindo da StartScreen), respeita ela.
          newInitialIndex = (initialTargetIndexFromRedux != -1)
              ? initialTargetIndexFromRedux
              : 1;
        } else if (initialTargetIndexFromRedux != -1) {
          // Se for usuário logado e houver uma navegação específica, usa ela.
          newInitialIndex = initialTargetIndexFromRedux;
        }
        // Se for usuário logado e não houver navegação específica, `newInitialIndex` permanece 0 (UserPage).

        // Garante que o índice calculado seja válido.
        if (newInitialIndex < 0 || newInitialIndex >= _pages.length) {
          newInitialIndex = isGuest ? 1 : 0; // Fallback seguro
        }

        if (newInitialIndex != _selectedIndex) {
          setState(() {
            _selectedIndex = newInitialIndex;
          });
        }

        if (initialTargetIndexFromRedux != -1) {
          storeInstance.dispatch(ClearTargetBottomNavAction());
        }
        // >>> FIM DA MODIFICAÇÃO <<<

        final initialViewModel = _UserCoinsViewModel.fromStore(storeInstance);
        _updatePremiumUI(initialViewModel.isPremium);
      }
    });
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
        return null; // Para LibraryPage e Chat, se não tiverem GlobalKey
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
      //case 3:
      //return "Chat IA";
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

  // Função para obter o próximo tema na sequência
  AppThemeOption _getNextTheme(AppThemeOption currentTheme) {
    final themes = AppThemeOption.values;
    final currentIndex = themes.indexOf(currentTheme);
    final nextIndex = (currentIndex + 1) % themes.length;
    return themes[nextIndex];
  }

  // Função para obter o ícone do tema atual
  IconData _getThemeIcon(AppThemeOption currentTheme) {
    switch (currentTheme) {
      case AppThemeOption.green:
        return Icons.eco_outlined; // Ícone para tema verde
      case AppThemeOption.septimaDark:
        return Icons.nightlight_round; // Ícone para tema escuro
      case AppThemeOption.septimaLight:
        return Icons.wb_sunny_outlined; // Ícone para tema claro
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeInstance = StoreProvider.of<AppState>(context, listen: false);
    final ThemeData currentThemeData =
        Theme.of(context); // Pega o ThemeData atual uma vez

    return StoreConnector<AppState, _MainAppScreenViewModel>(
      converter: (store) => _MainAppScreenViewModel.fromStore(store),
      onDidChange: (previousViewModel, newViewModel) {
        if (!mounted) return;
        if (newViewModel != null && previousViewModel != newViewModel) {
          // Adicionado null check para newViewModel
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
        // Se mainScreenViewModel for nulo (pode acontecer brevemente durante a inicialização do StoreConnector),
        // retorna um placeholder ou um widget de carregamento simples.
        if (mainScreenViewModel == null) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
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
                  // A cor do ícone será herdada do actionsIconTheme da AppBarTheme do tema atual
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
                            color: currentThemeData.colorScheme
                                .primary, // Usa cor primária do tema
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${coinsViewModel.userCoins}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              // Usa a cor do título da AppBar para consistência
                              color: currentThemeData
                                      .appBarTheme.titleTextStyle?.color ??
                                  currentThemeData.colorScheme.onPrimary,
                            ),
                          ),
                          if (coinsViewModel.userCoins < MAX_COINS_LIMIT)
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: currentThemeData.colorScheme
                                    .primary, // Usa cor primária do tema
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
                                      .withOpacity(0.7), // Um pouco mais suave
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
                  // As cores dos itens da BottomNavigationBar são definidas no AppTheme
                  onTap: (index) {
                    if (mounted) {
                      if (storeInstance.state.userState.isGuestUser &&
                          index == 0) {
                        showLoginRequiredDialog(context,
                            featureName: "seu perfil");
                        return;
                      }

                      int previousIndex = _selectedIndex;

                      // >>> INÍCIO DA MODIFICAÇÃO <<<
                      // Se o usuário está mudando para uma ABA DIFERENTE
                      if (previousIndex != index) {
                        // Tenta mostrar um anúncio ANTES de mudar a aba.
                        // O `then` garante que a mudança de aba ocorra DEPOIS que o anúncio
                        // for tentado (e possivelmente fechado).
                        interstitialManager
                            .tryShowInterstitial(
                                fromScreen:
                                    "MainAppScreen_TabChange_From_${_getAppBarTitle(previousIndex)}_To_${_getAppBarTitle(index)}")
                            .then((_) {
                          // Garante que o widget ainda está montado após o futuro do anúncio
                          if (mounted) {
                            setState(() {
                              _selectedIndex = index;
                            });

                            if (previousIndex == 1 && index != 1) {
                              // Saindo da BiblePage
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
                        // Se o usuário tocou na mesma aba, apenas atualiza o estado (sem anúncio)
                        // Embora, geralmente, tocar na mesma aba não faz nada visualmente aqui.
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
                      // >>> FIM DA MODIFICAÇÃO <<<
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
                    // BottomNavigationBarItem(
                    //     icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
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

// ViewModel para MainAppScreen (modificado para incluir themeOption)
class _MainAppScreenViewModel {
  final Map<String, dynamic>? userDetails;
  final int? targetBottomNavIndex;
  final bool isPremium;
  final AppThemeOption activeThemeOption; // NOVO

  _MainAppScreenViewModel({
    this.userDetails,
    this.targetBottomNavIndex,
    required this.isPremium,
    required this.activeThemeOption, // NOVO
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
      activeThemeOption:
          store.state.themeState.activeThemeOption, // NOVO: Pega do ThemeState
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MainAppScreenViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userDetails,
              other.userDetails) && // Use mapEquals de foundation.dart
          targetBottomNavIndex == other.targetBottomNavIndex &&
          isPremium == other.isPremium &&
          activeThemeOption == other.activeThemeOption; // NOVO

  @override
  int get hashCode =>
      userDetails.hashCode ^ // Use a hashCode do mapa diretamente
      targetBottomNavIndex.hashCode ^
      isPremium.hashCode ^
      activeThemeOption.hashCode; // NOVO
}

// Função showLoginRequiredDialog (como antes)
void showLoginRequiredDialog(BuildContext context,
    {String featureName = "esta funcionalidade"}) {
  // ... (implementação como antes)
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).dialogBackgroundColor,
      title: const Text("Login Necessário"),
      content: Text(
          "Para acessar $featureName, por favor, faça login ou crie uma conta."),
      actions: [
        TextButton(
          child: const Text("Cancelar"),
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        TextButton(
          child: const Text("Login / Cadastrar"),
          onPressed: () {
            Navigator.of(dialogContext).pop();
            final store = StoreProvider.of<AppState>(context, listen: false);
            if (store.state.userState.isGuestUser) {
              store.dispatch(UserExitedGuestModeAction());
            }
            Navigator.of(context, rootNavigator: true)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          },
        ),
      ],
    ),
  );
}
