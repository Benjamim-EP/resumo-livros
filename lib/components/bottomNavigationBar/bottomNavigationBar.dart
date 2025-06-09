// lib/components/bottomNavigationBar/bottomNavigationBar.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:resumo_dos_deuses_flutter/pages/bible_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/library_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart'; // Para rotas de navegação
import 'package:resumo_dos_deuses_flutter/pages/user_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart'; // Para rotas de navegação
import 'package:resumo_dos_deuses_flutter/pages/author_page.dart'; // Para rotas de navegação
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // Para SubscriptionStatusUpdatedAction
import 'package:resumo_dos_deuses_flutter/redux/middleware/ad_middleware.dart'; // Para MAX_COINS_LIMIT
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';

// ViewModel para o StoreConnector das moedas
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
          // Se endDate for nulo mas status é 'active', pode ser vitalício ou erro nos dados.
          // Assumindo premium para este caso.
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

class _UnderConstructionPlaceholder extends StatelessWidget {
  final String pageTitle;
  const _UnderConstructionPlaceholder({super.key, required this.pageTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removido o AppBar daqui, pois MainAppScreen já tem um
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
  int _selectedIndex = 0; // Padrão para UserPage

  final GlobalKey<NavigatorState> _userNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _bibleNavigatorKey =
      GlobalKey<NavigatorState>();
  // LibraryPage e Chat não precisam de GlobalKey se não tiverem navegação aninhada profunda

  late final List<Widget> _pages;
  ads.BannerAd? _bannerAd;
  StreamSubscription? _userDocSubscription;
  bool _isPremiumFromState = false; // Usado para controlar a exibição do banner

  @override
  void initState() {
    super.initState();
    _setupUserListener(); // Configura o listener do Firestore

    _pages = [
      _buildTabNavigator(_userNavigatorKey, const UserPage()), // Índice 0
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()), // Índice 1
      const LibraryPage(), // Índice 2 (Não precisa de _buildTabNavigator se não tiver rotas aninhadas)
      const _UnderConstructionPlaceholder(pageTitle: "Chat IA"), // Índice 3
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storeInstance =
            StoreProvider.of<AppState>(context, listen: false);
        final initialTargetIndex =
            storeInstance.state.userState.targetBottomNavIndex;
        final isGuest = storeInstance.state.userState.isGuestUser;

        int newInitialIndex = 0; // Padrão para UserPage (índice 0)

        if (isGuest && initialTargetIndex != null) {
          newInitialIndex = _calculateActualIndexFromTarget(initialTargetIndex);
          print(
              "MainAppScreen initState (Guest): Target index $initialTargetIndex, newInitialIndex $newInitialIndex");
        } else if (!isGuest && initialTargetIndex != null) {
          newInitialIndex = _calculateActualIndexFromTarget(initialTargetIndex);
          print(
              "MainAppScreen initState (Non-Guest): Target index $initialTargetIndex, newInitialIndex $newInitialIndex");
        }
        // Se não for convidado e não houver target, permanece 0 (UserPage)

        if (newInitialIndex != _selectedIndex) {
          setState(() {
            _selectedIndex = newInitialIndex;
          });
        }

        // Limpa o alvo APÓS usá-lo para a configuração inicial
        if (initialTargetIndex != null) {
          storeInstance.dispatch(ClearTargetBottomNavAction());
        }

        // Lógica original do ad premium
        final initialViewModel = _UserCoinsViewModel.fromStore(storeInstance);
        _updatePremiumUI(initialViewModel.isPremium);
      }
    });
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _setupUserListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final storeInstance = store; // Usando a instância global do store
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

          // Atualiza o estado Redux com os dados do usuário e da assinatura
          storeInstance.dispatch(SubscriptionStatusUpdatedAction(
            status: userData['subscriptionStatus'] ?? 'inactive',
            endDate: endDateDateTime,
            subscriptionId: userData['stripeSubscriptionId'] as String?,
            customerId: userData['stripeCustomerId'] as String?,
            priceId: userData['activePriceId'] as String?,
          ));
          storeInstance.dispatch(UserDetailsLoadedAction(userData));

          // Atualiza a UI relacionada ao status premium
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
        if (!_isPremiumFromState) {
          _initBannerAd();
        } else {
          _disposeBannerAd();
        }
      });
    }
  }

  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  void _initBannerAd() {
    if (_bannerAd != null || !mounted || _isPremiumFromState) return;
    _bannerAd = ads.BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: ads.AdSize.banner,
      request: const ads.AdRequest(),
      listener: ads.BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _bannerAd = ad as ads.BannerAd);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (mounted) setState(() => _bannerAd = null);
        },
      ),
    )..load();
  }

  Widget _buildTabNavigator(
      GlobalKey<NavigatorState>? navigatorKey, Widget child) {
    if (navigatorKey == null) {
      return child; // Para abas sem navegação aninhada
    }
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        WidgetBuilder? builder;
        if (settings.name == '/bookDetails') {
          final bookId = settings.arguments as String?;
          if (bookId != null) builder = (_) => BookDetailsPage(bookId: bookId);
        } else if (settings.name == '/authorPage') {
          final authorId = settings.arguments as String?;
          if (authorId != null) builder = (_) => AuthorPage(authorId: authorId);
        } else if (settings.name == '/queryResults') {
          builder = (_) => const QueryResultsPage();
        }
        // Adicione outras rotas específicas da aba aqui, se necessário
        builder ??= (_) => child; // Rota padrão para a aba
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
      case 2:
        return null; // LibraryPage não tem NavigatorKey neste exemplo
      case 3:
        return null; // Chat não tem NavigatorKey
      default:
        return _userNavigatorKey;
    }
  }

  Future<bool> _onWillPop() async {
    final currentKey = _currentNavigatorKey;
    if (currentKey == null ||
        currentKey.currentState == null ||
        !currentKey.currentState!.canPop()) {
      return true; // Permite fechar o app se não puder popar na aba atual
    }
    currentKey.currentState!.pop();
    return false; // Não fecha o app, apenas popa a rota na aba
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
        return "Chat IA";
      default:
        return "Septima";
    }
  }

  // Função auxiliar para calcular o índice real a partir do targetBottomNavIndex
  int _calculateActualIndexFromTarget(int targetIndexFromAction) {
    // Lógica ATUALIZADA para o novo fluxo de abas:
    // User (0), Bible (1), Library (2), Chat (3)
    if (targetIndexFromAction >= 0 && targetIndexFromAction < _pages.length) {
      return targetIndexFromAction;
    }
    return 0; // Fallback para a primeira aba (UserPage)
  }

  @override
  Widget build(BuildContext context) {
    final storeInstance = StoreProvider.of<AppState>(context, listen: false);

    return StoreConnector<AppState, _MainAppScreenViewModel>(
      converter: (store) => _MainAppScreenViewModel.fromStore(store),
      onDidChange: (previousViewModel, newViewModel) {
        if (!mounted) return;
        _updatePremiumUI(newViewModel.isPremium); // Atualiza UI do banner

        // Reage a mudanças no targetBottomNavIndex (para navegação programática entre abas)
        if (newViewModel.targetBottomNavIndex != null) {
          int targetIndex = newViewModel.targetBottomNavIndex!;
          int actualNewIndex = _calculateActualIndexFromTarget(targetIndex);

          if (actualNewIndex != _selectedIndex) {
            setState(() {
              _selectedIndex = actualNewIndex;
            });
            print(
                "MainAppScreen onDidChange: Mudando para aba $actualNewIndex devido a targetBottomNavIndex.");
          }
          storeInstance.dispatch(ClearTargetBottomNavAction());
        }
      },
      builder: (context, mainScreenViewModel) {
        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            appBar: AppBar(
              title: Text(_getAppBarTitle(_selectedIndex)),
              actions: [
                StoreConnector<AppState, _UserCoinsViewModel>(
                  converter: (store) => _UserCoinsViewModel.fromStore(store),
                  builder: (context, coinsViewModel) {
                    // Não mostra moedas para convidados ou premium
                    if (storeInstance.state.userState.isGuestUser ||
                        coinsViewModel.isPremium) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on,
                              color: Colors.amber, size: 22),
                          const SizedBox(width: 4),
                          Text(
                            '${coinsViewModel.userCoins}',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          if (coinsViewModel.userCoins < MAX_COINS_LIMIT)
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.greenAccent, size: 24),
                              tooltip: 'Ganhar Moedas',
                              onPressed: () {
                                storeInstance
                                    .dispatch(RequestRewardedAdAction());
                              },
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.check_circle,
                                  color: Colors.green, size: 22),
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
                if (!_isPremiumFromState && _bannerAd != null)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: ads.AdWidget(ad: _bannerAd!),
                  ),
                BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    if (mounted) {
                      // Se o usuário for convidado e tentar ir para a aba "User" (índice 0)
                      if (storeInstance.state.userState.isGuestUser &&
                          index == 0) {
                        showLoginRequiredDialog(context,
                            featureName: "seu perfil");
                        return; // Não muda de aba
                      }

                      int previousIndex = _selectedIndex;
                      setState(() {
                        _selectedIndex = index;
                      });

                      if (previousIndex == 1 && index != 1) {
                        // Saindo da BiblePage
                        final userState = storeInstance.state.userState;
                        if (userState.userId != null) {
                          // Só processa se for usuário logado
                          final pendingToAdd = userState.pendingSectionsToAdd;
                          final pendingToRemove =
                              userState.pendingSectionsToRemove;
                          if (pendingToAdd.isNotEmpty ||
                              pendingToRemove.isNotEmpty) {
                            storeInstance
                                .dispatch(ProcessPendingBibleProgressAction());
                          }
                        }
                      }
                      // Limpa qualquer alvo de navegação pendente do bottom nav, pois o usuário clicou.
                      // storeInstance.dispatch(ClearTargetBottomNavAction()); // Opcional aqui, já que onDidChange também limpa
                    }
                  },
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.account_circle),
                        label: 'User'), // Índice 0
                    BottomNavigationBarItem(
                        icon: Icon(Icons.book_outlined),
                        label: 'Bible'), // Índice 1
                    BottomNavigationBarItem(
                        icon: Icon(Icons.local_library_outlined),
                        label: 'Biblioteca'), // Índice 2
                    BottomNavigationBarItem(
                        icon: Icon(Icons.chat_bubble_outline),
                        label: 'Chat'), // Índice 3
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

  _MainAppScreenViewModel({
    this.userDetails,
    this.targetBottomNavIndex,
    required this.isPremium,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MainAppScreenViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userDetails, other.userDetails) &&
          targetBottomNavIndex == other.targetBottomNavIndex &&
          isPremium == other.isPremium;

  @override
  int get hashCode =>
      userDetails.hashCode ^ targetBottomNavIndex.hashCode ^ isPremium.hashCode;
}

// Função auxiliar para mostrar diálogo de login
void showLoginRequiredDialog(BuildContext context,
    {String featureName = "esta funcionalidade"}) {
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
            // A navegação para /login deve fazer com que o AuthCheck redirecione para LoginPage.
            // Se a StartScreenPage estiver na pilha abaixo de MainAppScreen, pode ser necessário popUntil.
            Navigator.of(context, rootNavigator: true)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          },
        ),
      ],
    ),
  );
}
