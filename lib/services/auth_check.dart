// Em: lib/services/auth_check.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:septima_biblia/design/theme.dart';
import 'package:septima_biblia/pages/start_screen_page.dart';
import 'package:septima_biblia/pages/login_page.dart';
import 'package:septima_biblia/pages/signup_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/bottomNavigationBar/bottomNavigationBar.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:septima_biblia/services/language_provider.dart';
import 'package:septima_biblia/services/navigation_service.dart';
import 'package:septima_biblia/main.dart'; // Para o navigatorKey
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:septima_biblia/services/notification_service.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return StoreConnector<AppState, _ViewModel>(
      converter: (store) => _ViewModel.fromStore(store),
      onInit: (store) {
        // O listener continua sendo a ponte crucial entre o Firebase e o Redux.
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null) {
            // A condição !isLoggedIn previne que o _processUserLogin seja chamado
            // múltiplas vezes se o token do usuário for atualizado em segundo plano.
            if (!store.state.userState.isLoggedIn) {
              _processUserLogin(store, user);
            }
          } else {
            // Se o usuário do Firebase for nulo, garante que o estado do Redux reflita isso.
            if (store.state.userState.isLoggedIn ||
                store.state.userState.isGuestUser) {
              store.dispatch(UserLoggedOutAction());
            }
          }
        });
      },
      builder: (context, vm) {
        // Se o estado Redux diz que o usuário está logado ou é convidado...
        if (vm.isLoggedIn || vm.isGuest) {
          // ...renderizamos o MaterialApp principal.
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            locale: languageProvider.appLocale,
            theme: vm.theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MainAppScreen(),
            onGenerateRoute: NavigationService.generateRoute,
          );
        }

        // Se o usuário NÃO está logado no Redux, mostramos o fluxo de autenticação.
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.greenTheme,
          locale: languageProvider.appLocale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
          ],
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // Enquanto o Firebase verifica o estado de autenticação...
              if (snapshot.connectionState == ConnectionState.waiting) {
                // ...mostramos um loader.
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              // Se o Firebase já tem um usuário (ex: login recente, app reiniciado)...
              if (snapshot.hasData) {
                // ...mostramos um loader. O onInit já chamou _processUserLogin
                // e logo o estado Redux (vm.isLoggedIn) será true, trocando para o MaterialApp principal.
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              // Se não há usuário no Firebase, mostramos a tela inicial para o usuário decidir.
              return const StartScreenPage();
            },
          ),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginPage());
              case '/signup':
                return MaterialPageRoute(
                    builder: (_) => const SignUpEmailPage());
              default:
                return MaterialPageRoute(
                    builder: (_) => const StartScreenPage());
            }
          },
        );
      },
    );
  }

  Future<void> _processUserLogin(Store<AppState> store, User user) async {
    print("AuthCheck: Iniciando processamento de login para ${user.uid}");

    final loginMethod = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'unknown';
    AnalyticsService.instance.logLogin(loginMethod);
    print("Analytics: Evento 'login' registrado com método: $loginMethod");

    store.dispatch(UserLoggedInAction(
      userId: user.uid,
      email: user.email ?? '',
      nome: user.displayName ?? 'Usuário',
    ));

    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      final docSnapshot = await userDocRef.get();
      Map<String, dynamic> userData;

      if (!docSnapshot.exists) {
        print(
            "AuthCheck: Novo usuário detectado. Criando documentos no Firestore...");

        AnalyticsService.instance.logSignUp(loginMethod);
        print("Analytics: Evento 'sign_up' registrado.");

        final initialName =
            user.displayName ?? user.email?.split('@')[0] ?? 'Novo Usuário';
        if (user.displayName == null || user.displayName!.isEmpty) {
          await user.updateDisplayName(initialName);
        }

        final newUserFirestoreData = {
          'userId': user.uid,
          'nome': initialName,
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'dataCadastro': FieldValue.serverTimestamp(),
          'selos': 10,
          'descrição': "Bem-vindo(a) ao Septima!",
          'topicSaves': {},
          'userCoins': 20,
          'lastRewardedAdWatchTime': null,
          'rewardedAdsWatchedToday': 0,
          'stripeCustomerId': null,
          'subscriptionStatus': 'inactive',
          'subscriptionEndDate': null,
          'stripeSubscriptionId': null,
          'activePriceId': null,
        };
        await userDocRef.set(newUserFirestoreData);
        userData = newUserFirestoreData;

        await FirebaseFirestore.instance
            .collection('userBibleProgress')
            .doc(user.uid)
            .set({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'rawReadingTime': 0,
          'bibleCompletionCount': 0,
          'currentProgressPercent': 0.0,
          'rankingScore': 0.0,
          'books': {},
        });

        print("AuthCheck: Documentos iniciais criados com sucesso.");
      } else {
        print(
            "AuthCheck: Usuário existente. Carregando detalhes do Firestore.");
        userData = docSnapshot.data()!;
      }

      // ===================================================================
      // ✅ INÍCIO DO NOVO BLOCO DE CÓDIGO PARA SEGMENTAÇÃO
      // ===================================================================

      // Detecta a fonte de instalação usando a flag de compilação
      const bool isPlayStoreBuild = bool.fromEnvironment('IS_PLAY_STORE');
      final String installSource =
          isPlayStoreBuild ? 'play_store' : 'website_apk';

      // --- ESTRATÉGIA 1: Tópicos do FCM (para notificações imediatas) ---
      try {
        final fcm = FirebaseMessaging.instance;
        if (isPlayStoreBuild) {
          // Inscreve no tópico da Play Store e remove do tópico do site (caso o usuário tenha trocado)
          await fcm.subscribeToTopic('play_store_users');
          await fcm.unsubscribeFromTopic('website_apk_users');
          print("FCM: Usuário inscrito no tópico 'play_store_users'.");
        } else {
          // Faz o inverso para a versão do site
          await fcm.subscribeToTopic('website_apk_users');
          await fcm.unsubscribeFromTopic('play_store_users');
          print("FCM: Usuário inscrito no tópico 'website_apk_users'.");
        }
      } catch (e) {
        print("FCM: Erro ao inscrever/desinscrever de tópicos: $e");
      }

      // --- ESTRATÉGIA 2: Propriedades do Analytics (para segmentação de longo prazo) ---
      try {
        await AnalyticsService.instance.setUserProperty(
          name: 'installation_source', // Nome da propriedade
          value: installSource, // Valor ('play_store' ou 'website_apk')
        );
        print(
            "Analytics: Propriedade do usuário 'installation_source' definida como '$installSource'.");
      } catch (e) {
        print("Analytics: Erro ao definir a propriedade do usuário: $e");
      }

      // ===================================================================
      // ✅ FIM DO NOVO BLOCO DE CÓDIGO
      // ===================================================================

      if (userData['username'] == null || userData['discriminator'] == null) {
        print(
            "AuthCheck: Usuário ${user.uid} não tem Septima ID. Tentando gerar agora...");
        try {
          final functions =
              FirebaseFunctions.instanceFor(region: "southamerica-east1");
          final callable = functions.httpsCallable('assignSeptimaId');
          await callable.call();
          print("AuthCheck: Chamada para assignSeptimaId enviada com sucesso.");
          store.dispatch(LoadUserDetailsAction());
        } catch (e) {
          print(
              "AuthCheck: ERRO ao chamar a função para gerar o Septima ID: $e");
        }
      }

      try {
        final statusString = userData['subscriptionStatus'] as String?;
        final endDate =
            (userData['subscriptionEndDate'] as Timestamp?)?.toDate();
        bool isPremium = false;
        if (statusString == 'active' &&
            endDate != null &&
            endDate.isAfter(DateTime.now())) {
          isPremium = true;
        }
        await AnalyticsService.instance.setPremiumStatus(isPremium);
        print(
            "Analytics: Propriedade de usuário 'is_premium' definida como '$isPremium'.");
      } catch (e) {
        print("Analytics: Erro ao definir propriedades do usuário: $e");
      }

      store.dispatch(UserDetailsLoadedAction(userData));

      print(
          "AuthCheck: Despachando ações para carregar dados de suporte (progresso, notas, etc.).");
      store.dispatch(LoadAllBibleProgressAction());
      store.dispatch(LoadUserNotesAction());
      store.dispatch(LoadUserHighlightsAction());
      store.dispatch(LoadAdLimitDataAction());
      store.dispatch(LoadUserDiariesAction());
      store.dispatch(LoadUserCollectionsAction());
      store.dispatch(LoadUserTagsAction());
      store.dispatch(LoadUserCommentHighlightsAction());
      store.dispatch(FetchRecommendedSermonsAction());
    } catch (e) {
      print(
          "AuthCheck: ERRO GERAL no processamento do login para ${user.uid}: $e");
      store.dispatch(UserLoggedOutAction());
    } finally {
      print("AuthCheck: Processamento de login concluído para ${user.uid}.");
    }

    try {
      final notificationService = NotificationService();
      await notificationService.saveFcmTokenToFirestore(user.uid);
    } catch (e) {
      print("AuthCheck: Erro ao tentar salvar o token FCM durante o login: $e");
    }
  }
}

// O ViewModel volta a ser simples, sem a flag de loading
class _ViewModel {
  final bool isLoggedIn;
  final bool isGuest;
  final ThemeData theme;

  _ViewModel(
      {required this.isLoggedIn, required this.isGuest, required this.theme});

  static _ViewModel fromStore(Store<AppState> store) {
    return _ViewModel(
      isLoggedIn: store.state.userState.isLoggedIn,
      isGuest: store.state.userState.isGuestUser,
      theme: store.state.themeState.activeThemeData,
    );
  }
}
