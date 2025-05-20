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
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/middleware/ad_middleware.dart'; // Para MAX_COINS_LIMIT
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
// Removido: import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // Não usado diretamente aqui
import 'package:redux/redux.dart';

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
  final String pageTitle; // Adicionar para personalizar o título
  const _UnderConstructionPlaceholder({super.key, required this.pageTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removida a AppBar daqui, pois será controlada pela MainAppScreen
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

  // Navigator Keys para cada aba principal com navegação interna
  final GlobalKey<NavigatorState> _userNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _bibleNavigatorKey =
      GlobalKey<NavigatorState>();
  // As abas "Cânticos" e "Chat" usarão _UnderConstructionPlaceholder,
  // então não precisam de NavigatorKeys dedicados se não tiverem navegação interna.
  // Se precisarem no futuro, adicione as chaves aqui.

  late final List<Widget> _pages;
  ads.BannerAd? _bannerAd;
  StreamSubscription? _userDocSubscription;
  bool _isPremiumFromState = false;

  @override
  void initState() {
    super.initState();
    _setupUserListener();
    _pages = [
      _buildTabNavigator(_userNavigatorKey, const UserPage()), // Índice 0
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()), // Índice 1
      // Para placeholders, podemos passar null como chave ou uma chave dummy se _buildTabNavigator exigir
      _buildTabNavigator(
          null,
          const _UnderConstructionPlaceholder(
              pageTitle: "Cânticos")), // Índice 2
      _buildTabNavigator(
          null,
          const _UnderConstructionPlaceholder(
              pageTitle: "Chat IA")), // Índice 3
    ];
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
    // Se navigatorKey for null (para placeholders), não envolvemos com Navigator,
    // apenas retornamos o child. Isso simplifica o _onWillPop.
    if (navigatorKey == null) {
      return child;
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
      // As abas 2 (Cânticos) e 3 (Chat) não têm navegação interna no momento.
      // Se _buildTabNavigator retorna o child diretamente para elas, _currentNavigatorKey será null.
      case 2:
        return null; // Cânticos (Placeholder)
      case 3:
        return null; // Chat (Placeholder)
      default:
        return _userNavigatorKey; // Fallback seguro
    }
  }

  Future<bool> _onWillPop() async {
    final currentKey = _currentNavigatorKey;
    // Se a aba atual não tem um NavigatorKey (é um placeholder) ou se o Navigator não pode dar pop,
    // permite que o WillPopScope feche o app/tela atual.
    if (currentKey == null ||
        currentKey.currentState == null ||
        !currentKey.currentState!.canPop()) {
      return true;
    }
    // Se pode dar pop, faz o pop e impede o fechamento do app.
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
        return "Cânticos";
      case 3:
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
        _updatePremiumUI(newViewModel.isPremium);

        if (newViewModel.targetBottomNavIndex != null) {
          int oldTargetIndex = newViewModel.targetBottomNavIndex!;
          int? newSelectedActualIndex;

          // Mapeamento de índices antigos (com Explore) para novos (sem Explore)
          // Antigo: User(0), Explore(1), Bible(2), Cântico(3), Chat(4)
          // Novo:   User(0),            Bible(1), Cântico(2), Chat(3)
          if (oldTargetIndex == 0) {
            // User
            newSelectedActualIndex = 0;
          } else if (oldTargetIndex == 1) {
            // Era Explore, redirecionar para User (ou não fazer nada)
            print("Redirecionamento da antiga aba Explore para Usuário.");
            newSelectedActualIndex = 0;
          } else if (oldTargetIndex > 1) {
            // Aba após Explore
            newSelectedActualIndex = oldTargetIndex - 1;
          }

          if (newSelectedActualIndex != null &&
              newSelectedActualIndex != _selectedIndex) {
            setState(() {
              _selectedIndex = newSelectedActualIndex!;
            });
          }
          StoreProvider.of<AppState>(context, listen: false)
              .dispatch(ClearTargetBottomNavAction());
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
                    if (coinsViewModel.isPremium) {
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
                                StoreProvider.of<AppState>(context,
                                        listen: false)
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
                      setState(() => _selectedIndex = index);
                      StoreProvider.of<AppState>(context, listen: false)
                          .dispatch(ClearTargetBottomNavAction());
                    }
                  },
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.account_circle), label: 'User'),
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

class _MainAppScreenViewModel {
  final Map<String, dynamic>? userDetails;
  final int?
      targetBottomNavIndex; // Este deve ser o índice ANTIGO, vindo do estado
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
      targetBottomNavIndex: store.state.userState
          .targetBottomNavIndex, // Pega o índice como está no store
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
