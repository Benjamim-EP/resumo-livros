// lib/components/bottomNavigationBar/bottomNavigationBar.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:resumo_dos_deuses_flutter/pages/bible_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/library_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/author_page.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart';
// Removido: import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // Não usado diretamente aqui
import 'package:resumo_dos_deuses_flutter/redux/middleware/ad_middleware.dart'; // Para MAX_COINS_LIMIT
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart'; // <<< IMPORTANTE PARA ProcessPendingBibleProgressAction

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
  final String pageTitle;
  const _UnderConstructionPlaceholder({required this.pageTitle});

  @override
  Widget build(BuildContext context) {
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
      _buildTabNavigator(
          null, const LibraryPage()), // <<< ALTERADO AQUI (Índice 2)
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
      // Obtém a instância global do store diretamente, se ela for exportada de store.dart
      // ou passa o store do context para cá se necessário.
      // Assumindo que 'store' é a instância global de redux/store.dart
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
      case 2:
        return null;
      case 3:
        return null;
      default:
        return _userNavigatorKey;
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

          if (oldTargetIndex == 0) {
            newSelectedActualIndex = 0;
          } else if (oldTargetIndex == 1) {
            print(
                "Redirecionamento da antiga aba Explore para Usuário (índice 0).");
            newSelectedActualIndex = 0;
          } else if (oldTargetIndex > 1) {
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
                      int previousIndex =
                          _selectedIndex; // Guarda o índice anterior

                      setState(() {
                        _selectedIndex = index; // Atualiza para o novo índice
                      });

                      // Verifica se o usuário estava na BiblePage (índice 1) e mudou para OUTRA aba
                      if (previousIndex == 1 && index != 1) {
                        // Usa o context daqui que é válido ou a instância global do store
                        final currentStore =
                            StoreProvider.of<AppState>(context, listen: false);
                        final userState = currentStore.state.userState;

                        if (userState.userId != null) {
                          final pendingToAdd = userState.pendingSectionsToAdd;
                          final pendingToRemove =
                              userState.pendingSectionsToRemove;
                          if (pendingToAdd.isNotEmpty ||
                              pendingToRemove.isNotEmpty) {
                            print(
                                "BottomNav onTap: Saindo da BiblePage com pendências. Disparando ProcessPendingBibleProgressAction.");
                            currentStore
                                .dispatch(ProcessPendingBibleProgressAction());
                          } else {
                            print(
                                "BottomNav onTap: Saindo da BiblePage sem pendências de progresso bíblico.");
                          }
                        }
                      }
                      // Limpa qualquer alvo de navegação pendente do bottom nav
                      StoreProvider.of<AppState>(context, listen: false)
                          .dispatch(ClearTargetBottomNavAction());
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
                        // <<< ALTERADO AQUI
                        icon: Icon(Icons.local_library_outlined), // Novo ícone
                        label: 'Biblioteca'), // Novo label - Índice 2
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
