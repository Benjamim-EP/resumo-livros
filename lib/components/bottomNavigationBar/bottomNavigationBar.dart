import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:resumo_dos_deuses_flutter/pages/bible_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/explore_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/author_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/rota_page.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 1;

  // Chaves para cada Navigator
  final GlobalKey<NavigatorState> _userNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _exploreNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _bibleNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _rotaNavigatorKey =
      GlobalKey<NavigatorState>();

  late final List<Widget> _pages;

  // Variáveis para verificar se o usuário é premium e para o anúncio
  bool isPremium = true;
  ads.BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();

    store.dispatch(LoadUserStatsAction());
    _pages = [
      _buildTabNavigator(_userNavigatorKey, UserPage()),
      _buildTabNavigator(_exploreNavigatorKey, const Explore()),
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()),
      _buildTabNavigator(_rotaNavigatorKey, RotaPage()),
    ];
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _updatePremiumStatus(Map<String, dynamic>? userDetails) {
    if (userDetails == null) return;

    final premiumData = userDetails['isPremium'] as Map<String, dynamic>?;

    if (premiumData != null) {
      final expirationTimestamp = premiumData['expiration'];

      if (expirationTimestamp != null && expirationTimestamp is Timestamp) {
        // Converte o Timestamp em um DateTime
        final expirationDate = expirationTimestamp.toDate();
        final now = DateTime.now();
        final isStillPremium = now.isBefore(expirationDate);

        // Atualiza o estado apenas se necessário
        if (isStillPremium != isPremium) {
          setState(() {
            isPremium = isStillPremium;

            // Inicializa ou remove o banner baseado no status premium
            if (!isPremium) {
              _initBannerAd();
            } else {
              _disposeBannerAd();
            }
          });
        }
      } else {
        print("Campo 'expiration' está ausente ou inválido.");
      }
    } else {
      print("Campo 'isPremium' está ausente.");
    }
  }

  void _disposeBannerAd() {
    if (_bannerAd != null) {
      _bannerAd?.dispose();
      _bannerAd = null;
      print("Banner removido.");
    }
  }

  void _initBannerAd() {
    if (_bannerAd != null) return;

    print("Inicializando banner...");
    _bannerAd = ads.BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: ads.AdSize.banner,
      request: const ads.AdRequest(),
      listener: ads.BannerAdListener(
        onAdLoaded: (ad) {
          print("Banner carregado com sucesso.");
          setState(() {
            _bannerAd = ad as ads.BannerAd;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print("Falha ao carregar o banner: ${err.message}");
          ad.dispose();
        },
      ),
    )..load();
  }

  Widget _buildTabNavigator(
      GlobalKey<NavigatorState> navigatorKey, Widget child) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name == '/bookDetails') {
          final bookId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => BookDetailsPage(bookId: bookId),
          );
        } else if (settings.name == '/authorPage') {
          final authorId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => AuthorPage(authorId: authorId),
          );
        } else if (settings.name == '/queryResults') {
          return MaterialPageRoute(
            builder: (_) => const QueryResultsPage(),
          );
        }
        return MaterialPageRoute(builder: (_) => child);
      },
    );
  }

  GlobalKey<NavigatorState> get _currentNavigatorKey {
    switch (_selectedIndex) {
      case 0:
        return _userNavigatorKey;
      case 1:
        return _exploreNavigatorKey;
      case 2:
        return _bibleNavigatorKey;
      case 3:
        return _rotaNavigatorKey;
      default:
        return _exploreNavigatorKey;
    }
  }

  Future<bool> _onWillPop() async {
    final currentNavigator = _currentNavigatorKey.currentState;
    if (currentNavigator != null && currentNavigator.canPop()) {
      currentNavigator.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    print("Estado atual: isPremium=$isPremium, bannerAd=${_bannerAd != null}");

    return StoreConnector<AppState, Map<String, dynamic>?>(
      converter: (store) => store.state.userState.userDetails,
      onDidChange: (prev, next) => _updatePremiumStatus(next),
      builder: (context, userDetails) {
        if (userDetails == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isPremium && _bannerAd != null)
                  Container(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: ads.AdWidget(ad: _bannerAd!),
                  ),
                BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    if (_selectedIndex == index) {
                      _currentNavigatorKey.currentState
                          ?.popUntil((route) => route.isFirst);
                    } else {
                      setState(() {
                        _selectedIndex = index;
                      });
                    }
                  },
                  selectedItemColor: Colors.greenAccent,
                  unselectedItemColor: Colors.white,
                  backgroundColor: Colors.black,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.account_circle),
                      label: 'User',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search),
                      label: 'Explore',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.book),
                      label: 'Bible',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.rocket),
                      label: 'Rota',
                    ),
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
