// lib/components/bottomNavigationBar/bottomNavigationBar.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:resumo_dos_deuses_flutter/pages/bible_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/author_page.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/middleware/ad_middleware.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart';
import 'package:redux/redux.dart';

// ViewModel para o StoreConnector das moedas
class _UserCoinsViewModel {
  final int userCoins;
  final bool isPremium; // Para decidir se mostra o botão de ganhar moedas

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
          premiumStatus =
              true; // Assinatura ativa sem data de término (ex: vitalícia)
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
  const _UnderConstructionPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Em Construção"),
        // backgroundColor já definido pelo tema
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.amber),
            SizedBox(height: 20),
            Text(
              'Esta seção está em construção!',
              style: TextStyle(
                fontSize: 20, /*color: Colors.white*/
              ), // Cor do tema
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Volte em breve para novidades.',
              style: TextStyle(
                fontSize: 16, /*color: Colors.white70*/
              ), // Cor do tema
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
  final GlobalKey<NavigatorState> _exploreNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _bibleNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _rotaNavigatorKey =
      GlobalKey<NavigatorState>(); // Era cântico
  final GlobalKey<NavigatorState> _chatNavigatorKey =
      GlobalKey<NavigatorState>();

  late final List<Widget> _pages;
  ads.BannerAd? _bannerAd;
  StreamSubscription? _userDocSubscription;
  bool _isPremiumFromState = false; // Estado local para controlar o banner

  @override
  void initState() {
    super.initState();
    _setupUserListener();
    _pages = [
      _buildTabNavigator(_userNavigatorKey, const UserPage()),
      _buildTabNavigator(_exploreNavigatorKey,
          const _UnderConstructionPlaceholder()), // Explore
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()),
      _buildTabNavigator(_rotaNavigatorKey,
          const _UnderConstructionPlaceholder()), // Cântico/Hymns
      _buildTabNavigator(
          _chatNavigatorKey, const _UnderConstructionPlaceholder()), // Chat
    ];
    // Carrega o estado premium inicial do Redux
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final initialViewModel = _UserCoinsViewModel.fromStore(
            StoreProvider.of<AppState>(context, listen: false));
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
          storeInstance.dispatch(
              UserDetailsLoadedAction(userData)); // Atualiza todos os detalhes

          // Atualiza o estado de premium para a UI do banner
          final currentViewModel = _UserCoinsViewModel.fromStore(storeInstance);
          _updatePremiumUI(currentViewModel.isPremium);
        }
      });
    }
  }

  // Nova função para atualizar a UI do banner com base no estado premium
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
    if (_bannerAd != null) {
      _bannerAd?.dispose();
      _bannerAd = null;
    }
  }

  void _initBannerAd() {
    if (_bannerAd != null || !mounted || _isPremiumFromState) {
      return; // Não carrega se for premium
    }
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
          setState(() {
            _bannerAd = ad as ads.BannerAd;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
            });
          }
        },
      ),
    )..load();
  }

  Widget _buildTabNavigator(
      GlobalKey<NavigatorState> navigatorKey, Widget child) {
    // ... (como antes)
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        if (child is _UnderConstructionPlaceholder) {
          return MaterialPageRoute(builder: (_) => child, settings: settings);
        }
        WidgetBuilder? builder;
        if (settings.name == '/bookDetails') {
          final bookId = settings.arguments as String?;
          if (bookId != null) {
            builder = (_) => BookDetailsPage(bookId: bookId);
          }
        } else if (settings.name == '/authorPage') {
          final authorId = settings.arguments as String?;
          if (authorId != null) {
            builder = (_) => AuthorPage(authorId: authorId);
          }
        } else if (settings.name == '/queryResults') {
          builder = (_) => const QueryResultsPage();
        }
        builder ??= (_) => child;
        return MaterialPageRoute(builder: builder, settings: settings);
      },
    );
  }

  GlobalKey<NavigatorState> get _currentNavigatorKey {
    // ... (como antes)
    switch (_selectedIndex) {
      case 0:
        return _userNavigatorKey;
      case 1:
        return _exploreNavigatorKey;
      case 2:
        return _bibleNavigatorKey;
      case 3:
        return _rotaNavigatorKey;
      case 4:
        return _chatNavigatorKey;
      default:
        return _userNavigatorKey;
    }
  }

  Future<bool> _onWillPop() async {
    // ... (como antes)
    if (_selectedIndex == 1 || _selectedIndex == 3 || _selectedIndex == 4) {
      return true;
    }
    final currentNavigator = _currentNavigatorKey.currentState;
    if (currentNavigator != null && currentNavigator.canPop()) {
      currentNavigator.pop();
      return false;
    }
    return true;
  }

  // Função para obter o título da AppBar com base no índice selecionado
  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return "Meu Perfil";
      case 1:
        return "Explorar";
      case 2:
        return "Bíblia";
      case 3:
        return "Cânticos"; // Ou Rotas, se for o caso
      case 4:
        return "Chat IA";
      default:
        return "Septima";
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _MainAppScreenViewModel>(
      converter: (store) => _MainAppScreenViewModel.fromStore(store),
      onDidChange: (previousViewModel, newViewModel) {
        if (!mounted) return;

        _updatePremiumUI(
            newViewModel.isPremium); // Atualiza o banner com base no ViewModel

        if (newViewModel.targetBottomNavIndex != null &&
            newViewModel.targetBottomNavIndex != _selectedIndex) {
          setState(() {
            _selectedIndex = newViewModel.targetBottomNavIndex!;
          });
          StoreProvider.of<AppState>(context, listen: false)
              .dispatch(ClearTargetBottomNavAction());
        }
      },
      builder: (context, mainScreenViewModel) {
        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            appBar: AppBar(
              // AppBar adicionada aqui
              title: Text(_getAppBarTitle(_selectedIndex)),
              // Estilo do AppBar será herdado do tema
              actions: [
                // StoreConnector para exibir moedas e botão de ganhar
                StoreConnector<AppState, _UserCoinsViewModel>(
                  converter: (store) => _UserCoinsViewModel.fromStore(store),
                  builder: (context, coinsViewModel) {
                    // Só mostra o sistema de moedas se o usuário não for premium
                    if (coinsViewModel.isPremium) {
                      return const SizedBox
                          .shrink(); // Não mostra nada para premium
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
                                StoreProvider.of<AppState>(context,
                                        listen: false)
                                    .dispatch(RequestRewardedAdAction());
                              },
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 22,
                              ),
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
                if (!_isPremiumFromState &&
                    _bannerAd != null) // Usa _isPremiumFromState
                  SizedBox(
                    // Envolve com SizedBox para garantir que o banner tenha espaço
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: ads.AdWidget(ad: _bannerAd!),
                  ),
                BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    if (mounted) {
                      setState(() {
                        _selectedIndex = index;
                      });
                      StoreProvider.of<AppState>(context, listen: false)
                          .dispatch(ClearTargetBottomNavAction());
                    }
                  },
                  // selectedItemColor e unselectedItemColor virão do tema
                  // backgroundColor virá do tema
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.account_circle), label: 'User'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.explore_outlined), label: 'Explore'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.book_outlined), label: 'Bible'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.music_note_outlined),
                        label: 'Cântico'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
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

// ViewModel para o StoreConnector principal da MainAppScreen (para targetBottomNavIndex e premium status)
class _MainAppScreenViewModel {
  final Map<String, dynamic>? userDetails; // Para verificar o status premium
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
