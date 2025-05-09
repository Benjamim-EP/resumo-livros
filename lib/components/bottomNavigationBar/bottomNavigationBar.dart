//lib/components/bottomNavigationBar/bottomNavigationBar.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:resumo_dos_deuses_flutter/pages/bible_page.dart';
// import 'package:resumo_dos_deuses_flutter/pages/chat_page.dart'; // <<< MODIFICAÇÃO MVP: Não precisa importar se for substituído
// import 'package:resumo_dos_deuses_flutter/pages/explore_page.dart'; // <<< MODIFICAÇÃO MVP: Não precisa importar se for substituído
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/author_page.dart';
// import 'package:resumo_dos_deuses_flutter/pages/hymns_page.dart'; // <<< MODIFICAÇÃO MVP: Não precisa importar se for substituído
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importar FirebaseAuth
import 'dart:async'; // Importar dart:async para StreamSubscription
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // Importar a ação específica
import 'package:redux/redux.dart';

// <<< MODIFICAÇÃO MVP: Widget Placeholder >>>
class _UnderConstructionPlaceholder extends StatelessWidget {
  const _UnderConstructionPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Adicionado Scaffold para aparência consistente
      appBar: AppBar(
        title: const Text("Em Construção"),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.amber),
            SizedBox(height: 20),
            Text(
              'Esta seção está em construção!',
              style: TextStyle(fontSize: 20, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Volte em breve para novidades.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
// <<< FIM MODIFICAÇÃO MVP >>>

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  // <<< MODIFICAÇÃO MVP: Iniciar na User Page (índice 0) ou Bible (índice 2)
  // Vamos manter User como inicial padrão (0)
  int _selectedIndex = 0; // <<< MODIFICAÇÃO MVP: Iniciar na aba User

  // Chaves para cada Navigator
  final GlobalKey<NavigatorState> _userNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _exploreNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _bibleNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _rotaNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _chatNavigatorKey =
      GlobalKey<NavigatorState>();

  late final List<Widget> _pages;

  // Variáveis para verificar se o usuário é premium e para o anúncio
  bool isPremium = false; // Começa como não premium até verificar
  ads.BannerAd? _bannerAd;
  StreamSubscription?
      _userDocSubscription; // Listener para o documento do usuário

  @override
  void initState() {
    super.initState();

    _setupUserListener(); // Configura o listener do Firestore

    // <<< MODIFICAÇÃO MVP: Atualiza a lista _pages >>>
    _pages = [
      // Índice 0: User (Ativo)
      _buildTabNavigator(_userNavigatorKey, UserPage()),
      // Índice 1: Explore (Em Construção)
      _buildTabNavigator(
          _exploreNavigatorKey, const _UnderConstructionPlaceholder()),
      // Índice 2: Bible (Ativo)
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()),
      // Índice 3: Cântico/Hymns (Em Construção)
      _buildTabNavigator(
          _rotaNavigatorKey, const _UnderConstructionPlaceholder()),
      // Índice 4: Chat (Em Construção)
      _buildTabNavigator(
          _chatNavigatorKey, const _UnderConstructionPlaceholder()),
    ];
    // <<< FIM MODIFICAÇÃO MVP >>>
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel(); // Cancela o listener ao sair
    _bannerAd?.dispose();
    super.dispose();
  }

  void _setupUserListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final storeInstance = store; // Usa o store global importado

      print(">>> MainAppScreen: Configurando listener para usuário $userId");

      _userDocSubscription?.cancel();

      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final userData = snapshot.data() as Map<String, dynamic>;
          print(
              ">>> MainAppScreen Listener: Dados do usuário atualizados no Firestore: Status='${userData['subscriptionStatus']}', EndDate='${(userData['subscriptionEndDate'] as Timestamp?)?.toDate()}'");
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
          // Atualiza userDetails geral também, para garantir consistência
          storeInstance.dispatch(UserDetailsLoadedAction(userData));
        } else {
          print(
              ">>> MainAppScreen Listener: Documento do usuário $userId não existe mais.");
        }
      }, onError: (error) {
        print(
            ">>> MainAppScreen Listener: Erro ao ouvir documento do usuário: $error");
      }, onDone: () {
        print(">>> MainAppScreen Listener: Listener finalizado.");
      });
    } else {
      print(
          ">>> MainAppScreen Listener: Usuário nulo, não é possível configurar listener.");
    }
  }

  void _updatePremiumStatus(Map<String, dynamic>? userDetails) {
    if (!mounted) return;

    bool shouldBePremium = false;
    if (userDetails != null) {
      final status = userDetails['subscriptionStatus'] as String?;
      final endDateTimestamp = userDetails['subscriptionEndDate'] as Timestamp?;

      if (status == 'active') {
        if (endDateTimestamp != null) {
          final expirationDate = endDateTimestamp.toDate();
          final now = DateTime.now();
          shouldBePremium = now.isBefore(expirationDate);
        } else {
          shouldBePremium = true;
        }
      }
    }

    if (shouldBePremium != isPremium) {
      print(
          ">>> MainAppScreen: Atualizando estado isPremium de $isPremium para $shouldBePremium");
      setState(() {
        isPremium = shouldBePremium;
        if (!isPremium) {
          _initBannerAd();
        } else {
          _disposeBannerAd();
        }
      });
    } else {
      print(
          ">>> MainAppScreen: Status premium ($isPremium) não mudou. Nenhuma atualização de UI necessária.");
    }
  }

  void _disposeBannerAd() {
    if (_bannerAd != null) {
      print(">>> MainAppScreen: Removendo banner Ad.");
      _bannerAd?.dispose();
      _bannerAd = null;
    }
  }

  void _initBannerAd() {
    if (_bannerAd != null || !mounted) return;

    print(">>> MainAppScreen: Inicializando banner Ad...");
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
          print(">>> MainAppScreen: Banner carregado com sucesso.");
          setState(() {
            _bannerAd = ad as ads.BannerAd;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print(
              ">>> MainAppScreen: Falha ao carregar o banner: ${err.message}");
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
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        // <<< MODIFICAÇÃO MVP: Simplificado - Se for placeholder, só mostra ele >>>
        if (child is _UnderConstructionPlaceholder) {
          return MaterialPageRoute(builder: (_) => child, settings: settings);
        }
        // <<< FIM MODIFICAÇÃO MVP >>>

        // Lógica de roteamento interno para cada aba ATIVA
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
        // Rota padrão da aba
        builder ??= (_) => child;

        return MaterialPageRoute(builder: builder, settings: settings);
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
      case 4:
        return _chatNavigatorKey;
      default:
        // <<< MODIFICAÇÃO MVP: Retorna a chave da User Page como padrão seguro
        return _userNavigatorKey;
      // <<< FIM MODIFICAÇÃO MVP >>>
    }
  }

  Future<bool> _onWillPop() async {
    // <<< MODIFICAÇÃO MVP: Se a aba atual for uma desativada, permite sair direto >>>
    if (_selectedIndex == 1 || _selectedIndex == 3 || _selectedIndex == 4) {
      return true; // Permite fechar o app se estiver numa aba desativada
    }
    // <<< FIM MODIFICAÇÃO MVP >>>

    final currentNavigator = _currentNavigatorKey.currentState;
    if (currentNavigator != null && currentNavigator.canPop()) {
      currentNavigator.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    print(
        ">>> MainAppScreen Build: Estado atual isPremium=$isPremium, bannerAd=${_bannerAd != null}, selectedIndex=$_selectedIndex");

    return StoreConnector<AppState, _MainAppScreenViewModel>(
      converter: (store) => _MainAppScreenViewModel.fromStore(store),
      // Usaremos onDidChange para reagir à mudança do targetBottomNavIndex
      onDidChange: (previousViewModel, newViewModel) {
        print(
            ">>> MainAppScreen StoreConnector.onDidChange: Estado Redux mudou.");
        if (previousViewModel?.userDetails != newViewModel.userDetails) {
          _updatePremiumStatus(newViewModel.userDetails);
        }

        // Verifica se a aba alvo mudou e se é válida
        if (newViewModel.targetBottomNavIndex != null &&
            newViewModel.targetBottomNavIndex != _selectedIndex) {
          print(
              ">>> MainAppScreen: targetBottomNavIndex mudou para ${newViewModel.targetBottomNavIndex}. Atualizando _selectedIndex.");
          setState(() {
            _selectedIndex = newViewModel.targetBottomNavIndex!;
          });
          // Limpa o targetBottomNavIndex para não ficar trocando de aba repetidamente
          StoreProvider.of<AppState>(context, listen: false)
              .dispatch(ClearTargetBottomNavAction());
        }
      },
      // Não precisamos reconstruir o widget inteiro por causa do targetBottomNavIndex,
      // pois o onDidChange já lida com a lógica. Mas manter true é seguro.
      rebuildOnChange: true,
      builder: (context, viewModel) {
        // Renomeado para viewModel
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
                    alignment: Alignment.center,
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: ads.AdWidget(ad: _bannerAd!),
                  ),
                BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                    // Se o usuário clicar numa aba, limpamos qualquer navegação programática pendente
                    StoreProvider.of<AppState>(context, listen: false)
                        .dispatch(ClearTargetBottomNavAction());
                  },
                  selectedItemColor: Colors.greenAccent,
                  unselectedItemColor: Colors.white70,
                  backgroundColor: Colors.black,
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

class _MainAppScreenViewModel {
  final Map<String, dynamic>? userDetails;
  final int? targetBottomNavIndex;

  _MainAppScreenViewModel({
    this.userDetails,
    this.targetBottomNavIndex,
  });

  static _MainAppScreenViewModel fromStore(Store<AppState> store) {
    return _MainAppScreenViewModel(
      userDetails: store.state.userState.userDetails,
      targetBottomNavIndex: store.state.userState.targetBottomNavIndex,
    );
  }

  // Adicionar operador == e hashCode para otimizar o StoreConnector
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MainAppScreenViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(
              userDetails, other.userDetails) && // Usar mapEquals para mapas
          targetBottomNavIndex == other.targetBottomNavIndex;

  @override
  int get hashCode => userDetails.hashCode ^ targetBottomNavIndex.hashCode;
}
