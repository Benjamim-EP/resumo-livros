// integration_test/app_start_and_login_test.dart

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:septima_biblia/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // ✅ PASSO 1: SUBSTITUA 'SEU_IP_AQUI' PELO SEU ENDEREÇO IPV4 LOCAL
  // Para encontrar seu IP, abra o CMD e digite 'ipconfig'
  const String host = '192.168.1.58';

  const int firestorePort = 8080;
  const int authPort = 9099;

  group('Fluxo de Autenticação e Acesso', () {
    setUpAll(() async {
      // Inicializa o Firebase e aponta para os emuladores usando o IP explícito
      await Firebase.initializeApp();
      print("Firebase App inicializado para o teste.");

      try {
        await FirebaseAuth.instance.useAuthEmulator(host, authPort);
        FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
        print("Emuladores configurados para usar o host explícito: $host");

        await FirebaseAuth.instance.signOut();
        print("Sessão de autenticação limpa.");
      } catch (e) {
        print("ERRO CRÍTICO AO CONECTAR COM EMULADORES no setUpAll: $e");
        print(
            "Verifique se os emuladores do Firebase estão rodando e se o IP '$host' está correto.");
        rethrow;
      }
    });

    testWidgets(
        'dado um usuário logado, deve iniciar na MainAppScreen e exibir seus dados',
        (WidgetTester tester) async {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      User? testUser;
      final testName = "Usuário Teste Final";

      // --- PREPARAÇÃO: Criar o usuário ANTES de iniciar a UI ---
      try {
        final testEmail =
            "final-test-${DateTime.now().millisecondsSinceEpoch}@test.com";
        final testPassword = "password123";

        final userCredential = await auth.createUserWithEmailAndPassword(
            email: testEmail, password: testPassword);
        await userCredential.user?.updateDisplayName(testName);
        testUser = auth.currentUser;

        print(
            "Usuário de teste ${testUser!.uid} criado com sucesso no emulador.");
      } catch (e) {
        fail(
            "FALHA NA ETAPA DE PREPARAÇÃO: Não foi possível criar o usuário no emulador. Erro: $e");
      }

      // --- INICIAR O APP ---
      app.main();

      print("Teste: App iniciado com usuário já logado. Aguardando UI...");
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // --- VERIFICAÇÃO ---
      expect(find.byType(BottomNavigationBar), findsOneWidget,
          reason: "A MainAppScreen não foi carregada.");

      final userDoc =
          await firestore.collection('users').doc(testUser!.uid).get();
      expect(userDoc.exists, isTrue,
          reason: "Documento do usuário não foi criado no Firestore.");

      expect(find.text(testName), findsOneWidget,
          reason: "O nome do usuário de teste não foi encontrado na UI.");

      print("Teste: Fluxo de usuário logado verificado com sucesso.");
    });
  });
}
