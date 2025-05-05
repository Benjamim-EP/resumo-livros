import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as ads;
import 'package:resumo_dos_deuses_flutter/pages/bible_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/chat_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/explore_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/author_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/hymns_page.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importar FirebaseAuth
import 'dart:async'; // Importar dart:async para StreamSubscription
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // Importar a ação específica

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 1; // Iniciar na aba Explore por padrão

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

    // Carrega dados iniciais essenciais do usuário via Redux
    // store.dispatch(LoadUserStatsAction()); // <- O listener abaixo pode substituir isso se carregar tudo
    // store.dispatch(LoadUserDetailsAction()); // <- O listener abaixo pode substituir isso

    _setupUserListener(); // Configura o listener do Firestore

    _pages = [
      _buildTabNavigator(_userNavigatorKey, UserPage()),
      _buildTabNavigator(_exploreNavigatorKey, const Explore()),
      _buildTabNavigator(_bibleNavigatorKey, const BiblePage()),
      _buildTabNavigator(_rotaNavigatorKey,
          const HymnsPage()), // Ajustado para const se não tiver estado
      _buildTabNavigator(_chatNavigatorKey, const ChatPage()),
    ];

    // Carrega o estado premium inicial (pode ser feito aqui ou no onInit do StoreConnector)
    // _updatePremiumStatus(store.state.userState.userDetails); //<- Removido, onDidChange fará isso
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
      // Não precisamos pegar o store aqui, ele será pego dentro do listen

      print(">>> MainAppScreen: Configurando listener para usuário $userId");

      // Cancela listener anterior, se houver
      _userDocSubscription?.cancel();

      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots() // Escuta mudanças em TEMPO REAL
          .listen((DocumentSnapshot snapshot) {
        // Obter a instância do store AQUI, dentro do callback, para garantir que temos contexto se necessário
        // Embora para despachar não precise do context, é uma boa prática.
        final storeInstance = store; // Usa o store global importado

        if (snapshot.exists && snapshot.data() != null) {
          final userData = snapshot.data() as Map<String, dynamic>;
          print(
              ">>> MainAppScreen Listener: Dados do usuário atualizados no Firestore: Status='${userData['subscriptionStatus']}', EndDate='${(userData['subscriptionEndDate'] as Timestamp?)?.toDate()}'");
          final Timestamp? endDateTimestamp =
              userData['subscriptionEndDate'] as Timestamp?;
          // 2. Converta para DateTime? (se o timestamp não for nulo)
          final DateTime? endDateDateTime = endDateTimestamp?.toDate();
          // Despacha a ação específica com os dados da assinatura
          storeInstance.dispatch(SubscriptionStatusUpdatedAction(
            status: userData['subscriptionStatus'] ?? 'inactive',
            endDate: endDateDateTime, // <<< PASSA O DateTime? CONVERTIDO
            subscriptionId: userData['stripeSubscriptionId'] as String?,
            customerId: userData['stripeCustomerId'] as String?,
            priceId: userData['activePriceId'] as String?,
          ));
          // Pode também despachar a ação geral se outras partes do app precisarem de TODOS os dados atualizados
          // storeInstance.dispatch(UserDetailsLoadedAction(userData));
        } else {
          print(
              ">>> MainAppScreen Listener: Documento do usuário $userId não existe mais.");
          // Se o documento for excluído, talvez despachar uma ação de logout?
          // storeInstance.dispatch(UserLoggedOutAction()); // Exemplo
        }
      }, onError: (error) {
        print(
            ">>> MainAppScreen Listener: Erro ao ouvir documento do usuário: $error");
        // Considerar despachar uma ação de erro
      }, onDone: () {
        print(">>> MainAppScreen Listener: Listener finalizado.");
        // O listener pode ser finalizado se a stream for fechada (raro para snapshots)
      });
    } else {
      print(
          ">>> MainAppScreen Listener: Usuário nulo, não é possível configurar listener.");
    }
  }

  // Esta função agora será chamada automaticamente pelo onDidChange do StoreConnector
  void _updatePremiumStatus(Map<String, dynamic>? userDetails) {
    if (!mounted) return; // Não atualiza estado se o widget não estiver montado

    bool shouldBePremium = false; // Calcula o status baseado nos dados atuais
    if (userDetails != null) {
      final status = userDetails['subscriptionStatus'] as String?;
      final endDateTimestamp = userDetails['subscriptionEndDate'] as Timestamp?;

      if (status == 'active') {
        if (endDateTimestamp != null) {
          final expirationDate = endDateTimestamp.toDate();
          final now = DateTime.now();
          shouldBePremium = now.isBefore(expirationDate);
        } else {
          // Ativo sem data de fim? Considerar premium (ex: trial vitalício?)
          shouldBePremium = true;
        }
      }
    }

    // Atualiza o estado local APENAS se o status calculado mudou
    if (shouldBePremium != isPremium) {
      print(
          ">>> MainAppScreen: Atualizando estado isPremium de $isPremium para $shouldBePremium");
      setState(() {
        isPremium = shouldBePremium;
        if (!isPremium) {
          _initBannerAd(); // Mostra banner se não for premium
        } else {
          _disposeBannerAd(); // Remove banner se for premium
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
    if (_bannerAd != null || !mounted)
      return; // Não recria se já existe ou se não está montado

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
          } // Descarta se saiu da tela antes de carregar
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
            }); // Garante que banner seja nulo no estado
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
        // Lógica de roteamento interno para cada aba
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
        return _exploreNavigatorKey;
    }
  }

  Future<bool> _onWillPop() async {
    final currentNavigator = _currentNavigatorKey.currentState;
    // Se o navigator da aba atual puder voltar, volte nele. Senão, permite fechar o app.
    if (currentNavigator != null && currentNavigator.canPop()) {
      currentNavigator.pop();
      return false; // Impede que o WillPopScope feche o app
    }
    return true; // Permite fechar o app
  }

  @override
  Widget build(BuildContext context) {
    print(
        ">>> MainAppScreen Build: Estado atual isPremium=$isPremium, bannerAd=${_bannerAd != null}");

    return StoreConnector<AppState, Map<String, dynamic>?>(
      converter: (store) => store.state.userState.userDetails,
      // ATENÇÃO: onInit aqui pode causar chamadas duplicadas se o listener já estiver ativo.
      // É melhor confiar no listener para a atualização inicial após o login.
      // Removido onInit para evitar redundância com o listener.
      // onInit: (store) { ... },
      // onDidChange REAGE a mudanças no estado Redux (causadas pelo listener)
      onDidChange: (previousViewModel, viewModel) {
        print(
            ">>> MainAppScreen StoreConnector.onDidChange: Estado Redux mudou.");
        _updatePremiumStatus(viewModel);
      },
      // Rebuilda explicitamente quando o userDetails muda para garantir que _updatePremiumStatus seja chamado
      rebuildOnChange: true, // Ou false se onDidChange for suficiente
      builder: (context, userDetails) {
        // O builder agora confia que onDidChange atualizará o estado 'isPremium'
        // Não precisa mais da verificação inicial de null aqui se o listener estiver ativo.

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
                // Exibe o banner SE não for premium E o banner estiver carregado
                if (!isPremium && _bannerAd != null)
                  Container(
                    alignment: Alignment.center, // Centraliza o anúncio
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: ads.AdWidget(ad: _bannerAd!),
                  ),
                BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    if (_selectedIndex == index) {
                      // Se clicar na aba atual, volta para a raiz dela
                      _currentNavigatorKey.currentState
                          ?.popUntil((route) => route.isFirst);
                    } else {
                      // Muda para a nova aba
                      setState(() {
                        _selectedIndex = index;
                      });
                    }
                  },
                  selectedItemColor:
                      Colors.greenAccent, // Cor do item selecionado
                  unselectedItemColor:
                      Colors.white70, // Cor dos itens não selecionados
                  backgroundColor: Colors.black, // Fundo da barra
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.account_circle), label: 'User'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.explore_outlined),
                        label: 'Explore'), // Ícone Explore
                    BottomNavigationBarItem(
                        icon: Icon(Icons.book_outlined),
                        label: 'Bible'), // Ícone Bíblia
                    BottomNavigationBarItem(
                        icon: Icon(Icons.music_note_outlined),
                        label: 'Cântico'), // Ícone Hino/Cântico
                    BottomNavigationBarItem(
                        icon: Icon(Icons.chat_bubble_outline),
                        label: 'Chat'), // Ícone Chat
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
