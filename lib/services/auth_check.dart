// lib/services/auth_check.dart
import 'dart:async'; // Para StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// A LoginPage será retornada diretamente pelo build, então pode não precisar ser navegada globalmente
import 'package:resumo_dos_deuses_flutter/pages/login_page.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/components/bottomNavigationBar/bottomNavigationBar.dart'; // MainAppScreen
// Removida a importação da StartScreenPage

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  StreamSubscription<User?>? _authSubscription;
  User? _currentUser;
  bool _processingUser = false;
  bool _initialAuthEventReceived = false;

  @override
  void initState() {
    super.initState();
    print("AuthCheck initState: Widget inicializado.");
  }

  void _setupAuthListener(Store<AppState> store) {
    if (_authSubscription != null) {
      return;
    }
    print(
        "AuthCheck _setupAuthListener: Configurando listener para authStateChanges.");
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      print(
          "AuthCheck authStateChanges LISTENER: Novo estado. User ID: ${user?.uid}. Widget montado: $mounted");
      if (!mounted) {
        print(
            "AuthCheck authStateChanges LISTENER: _AuthCheckState não está montado. Abortando.");
        return;
      }

      setState(() {
        _currentUser = user;
        _initialAuthEventReceived = true;
        if (user != null && !_processingUser) {
          _processUser(
              user, store); // _processUser agora lida com _processingUser
        } else if (user == null) {
          _processingUser = false;
          store.dispatch(UserLoggedOutAction());
        }
      });
    }, onError: (error) {
      print("AuthCheck authStateChanges LISTENER: Erro no stream: $error");
      if (mounted)
        setState(() {
          _currentUser = null;
          _initialAuthEventReceived = true;
          _processingUser = false;
        });
    }, onDone: () {
      print(
          "AuthCheck authStateChanges LISTENER: Stream de autenticação finalizado.");
      if (mounted && !_initialAuthEventReceived) {
        setState(() {
          _initialAuthEventReceived = true;
          _currentUser = null;
          _processingUser = false;
        });
      }
    });
  }

  @override
  void dispose() {
    print("AuthCheck dispose: Cancelando subscrição de autenticação.");
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _processUser(User user, Store<AppState> store) async {
    if (!mounted) {
      print(
          "AuthCheck: _processUser - _AuthCheckState não montado no início. Abortando.");
      return;
    }

    if (mounted) setState(() => _processingUser = true);
    print(
        "AuthCheck: _processUser - Iniciando para usuário ${user.uid}. _processingUser = true.");

    if (store.state.userState.userId != user.uid ||
        !store.state.userState.isLoggedIn) {
      store.dispatch(UserLoggedInAction(
        userId: user.uid,
        email: user.email ?? '',
        nome: user.displayName ?? '',
      ));
    }

    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      final docSnapshot = await userDocRef.get();

      if (!mounted) {
        print("AuthCheck: _processUser - Desmontado após get do Firestore.");
        return;
      }

      if (!docSnapshot.exists) {
        print(
            "AuthCheck: _processUser - Novo usuário ${user.uid}. Criando documentos no Firestore.");
        final String initialName = user.displayName ?? 'Novo Usuário Septima';
        final String initialEmail =
            user.email ?? 'email.desconhecido@example.com';
        final String initialPhotoURL = user.photoURL ?? '';

        final Map<String, dynamic> newUserFirestoreData = {
          'userId': user.uid,
          'nome': initialName,
          'email': initialEmail,
          'photoURL': initialPhotoURL,
          'dataCadastro': FieldValue.serverTimestamp(),
          'Dias': 0,
          'Livros': 0,
          'Tópicos': 0,
          'selos': 10,
          'descrição': "Bem-vindo(a) ao Septima!",
          'topicSaves': {},
          'userCoins': 100,
          'lastRewardedAdWatchTime': null,
          'rewardedAdsWatchedToday': 0,
          'stripeCustomerId': null,
          'subscriptionStatus': 'inactive',
          'subscriptionEndDate': null,
          'stripeSubscriptionId': null,
          'activePriceId': null,
          'userFeatures': {},
          'indicacoes': {},
        };
        await userDocRef.set(newUserFirestoreData);
        print("AuthCheck: Documento principal /users/${user.uid} criado.");

        final WriteBatch batch = FirebaseFirestore.instance.batch();
        final now = FieldValue.serverTimestamp();
        final commonData = {'userId': user.uid, 'createdAt': now};

        batch.set(
            FirebaseFirestore.instance
                .collection('userBibleProgress')
                .doc(user.uid),
            {
              ...commonData,
              'books': {},
              'lastReadBookAbbrev': null,
              'lastReadChapter': null,
              'lastReadTimestamp': null
            });
        batch.set(
            FirebaseFirestore.instance
                .collection('userCommentHighlights')
                .doc(user.uid),
            commonData);
        batch.set(
            FirebaseFirestore.instance
                .collection('userVerseHighlights')
                .doc(user.uid),
            commonData);
        batch.set(
            FirebaseFirestore.instance
                .collection('userVerseNotes')
                .doc(user.uid),
            commonData);

        await batch.commit();
        print(
            "AuthCheck: Documentos base para progresso, etc., criados para ${user.uid}.");

        store.dispatch(UserDetailsLoadedAction(newUserFirestoreData));
      } else {
        print(
            "AuthCheck: _processUser - Usuário ${user.uid} existente. Verificando/migrando dados.");
        final userDataFromFirestore = docSnapshot.data()!;
        Map<String, dynamic> migratedData = Map.from(userDataFromFirestore);
        bool needsMigrationUpdateInUsersDoc = false;

        if (migratedData['userCoins'] == null) {
          migratedData['userCoins'] = 100;
          needsMigrationUpdateInUsersDoc = true;
        }
        if (migratedData['rewardedAdsWatchedToday'] == null) {
          migratedData['rewardedAdsWatchedToday'] = 0;
          needsMigrationUpdateInUsersDoc = true;
        }
        if (migratedData['subscriptionStatus'] == null) {
          migratedData['subscriptionStatus'] = 'inactive';
          needsMigrationUpdateInUsersDoc = true;
        }

        if (needsMigrationUpdateInUsersDoc) {
          await userDocRef.update(migratedData);
          print("AuthCheck: Dados de migração aplicados a /users/${user.uid}.");
        }
        store.dispatch(UserDetailsLoadedAction(migratedData));

        final WriteBatch migrationBatch = FirebaseFirestore.instance.batch();
        bool needsMigrationBatchCommit = false;
        final commonData = {
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp()
        };

        Future<void> ensureDocExistsWithInitialData(
            DocumentReference docRef, Map<String, dynamic> initialData) async {
          final snap = await docRef.get();
          if (!snap.exists) {
            migrationBatch.set(docRef, initialData);
            needsMigrationBatchCommit = true;
          }
        }

        await ensureDocExistsWithInitialData(
            FirebaseFirestore.instance
                .collection('userBibleProgress')
                .doc(user.uid),
            {
              ...commonData,
              'books': {},
              'lastReadBookAbbrev': null,
              'lastReadChapter': null,
              'lastReadTimestamp': null
            });
        await ensureDocExistsWithInitialData(
            FirebaseFirestore.instance
                .collection('userCommentHighlights')
                .doc(user.uid),
            commonData);
        await ensureDocExistsWithInitialData(
            FirebaseFirestore.instance
                .collection('userVerseHighlights')
                .doc(user.uid),
            commonData);
        await ensureDocExistsWithInitialData(
            FirebaseFirestore.instance
                .collection('userVerseNotes')
                .doc(user.uid),
            commonData);

        if (needsMigrationBatchCommit) {
          await migrationBatch.commit();
          print(
              "AuthCheck (Migração): Documentos de novas coleções criados/verificados para ${user.uid}.");
        }
      }

      if (!mounted) {
        print(
            "AuthCheck: _processUser - Desmontado antes de despachar LoadAdLimitDataAction.");
        return;
      }
      store.dispatch(LoadAdLimitDataAction());
      print("AuthCheck: _processUser - LoadAdLimitDataAction despachada.");
    } catch (e, s) {
      print(
          "AuthCheck: _processUser - Erro durante o processamento do usuário ${user.uid}: $e");
      print("AuthCheck: _processUser - StackTrace: $s");
    } finally {
      if (mounted) {
        setState(() {
          _processingUser = false;
        });
        print(
            "AuthCheck: _processUser - Finalizado para ${user.uid}. _processingUser = false.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        "AuthCheck: Build method. _initialAuthEventReceived: $_initialAuthEventReceived, CurrentUser: ${_currentUser?.uid}, Processing: $_processingUser");

    return StoreBuilder<AppState>(
      onInit: (store) {
        _setupAuthListener(store);
      },
      builder: (context, store) {
        if (!_initialAuthEventReceived) {
          print(
              "AuthCheck builder: Aguardando primeiro evento do authStateChanges. Mostrando loader.");
          return const Scaffold(
              key: ValueKey("AuthCheckAwaitingInitialEvent"),
              body: Center(
                  child: CircularProgressIndicator(
                      key: ValueKey("AuthCheckInitialEventLoader"))));
        }

        if (_currentUser == null) {
          print("AuthCheck builder: Usuário NULO. Mostrando LoginPage.");
          return const LoginPage(); // <<< ALTERADO: Vai para LoginPage em vez de StartScreenPage
        }

        if (_processingUser) {
          print(
              "AuthCheck builder: Usuário NÃO NULO (${_currentUser!.uid}), mas _processingUser é TRUE. Mostrando loader de processamento.");
          return const Scaffold(
              key: ValueKey("AuthCheckProcessingUserUI"),
              body: Center(
                  child: CircularProgressIndicator(
                      key: ValueKey("AuthCheckProcessingLoader"))));
        }

        if (store.state.userState.userId == _currentUser!.uid &&
            store.state.userState.isLoggedIn) {
          print(
              "AuthCheck builder: Usuário logado e processado (${_currentUser!.uid}). Mostrando MainAppScreen.");
          return const MainAppScreen();
        }

        print(
            "AuthCheck builder: Fallback/Carregamento. User Firebase: ${_currentUser?.uid}, Redux User: ${store.state.userState.userId}. Mostrando loader.");
        return const Scaffold(
          key: ValueKey("AuthCheckFallbackOrSyncing"),
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
