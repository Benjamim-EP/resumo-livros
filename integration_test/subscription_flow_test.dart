// integration_test/subscription_flow_test.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:septima_biblia/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/components/buttons/animated_premium_button.dart';
import 'package:septima_biblia/components/buttons/animated_infinity_icon.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // ✅ CORREÇÃO: Usando a mesma configuração de host do teste anterior
  const String host = '192.168.1.58'; // <--- SEU IP LOCAL
  const int firestorePort = 8080;
  const int authPort = 9099;

  group('Fluxo de Assinatura Premium', () {
    setUpAll(() async {
      await Firebase.initializeApp();
      await FirebaseAuth.instance.useAuthEmulator(host, authPort);
      FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
      print("Firebase configurado para usar o host explícito: $host");
    });

    testWidgets(
        'deve permitir que um usuário não-premium assine e veja a UI premium',
        (WidgetTester tester) async {
      // --- PREPARAÇÃO (sem alterações) ---
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      await auth.signOut();
      final testEmail =
          "non-premium-user-${DateTime.now().millisecondsSinceEpoch}@test.com";
      final testPassword = "password123";
      final userCredential = await auth.createUserWithEmailAndPassword(
          email: testEmail, password: testPassword);
      final user = userCredential.user;
      expect(user, isNotNull);
      await firestore.collection('users').doc(user!.uid).set({
        'nome': 'Usuário Comum',
        'subscriptionStatus': 'inactive',
      });

      // --- INICIAR APP E NAVEGAR ---
      app.main();
      await tester.pumpAndSettle(); // Espera a tela inicial carregar

      // ✅ CORREÇÃO: Finder mais robusto para o botão
      final premiumButtonFinder = find.byType(AnimatedPremiumButton);
      expect(premiumButtonFinder, findsOneWidget);

      await tester.tap(premiumButtonFinder);
      await tester.pumpAndSettle();

      // --- PÁGINA DE ASSINATURA ---
      expect(find.byType(SubscriptionSelectionPage), findsOneWidget);
      print("Teste: Página de Assinatura aberta.");

      final monthlyPlanButtonFinder =
          find.widgetWithText(InkWell, "Assinar Plano Mensal");
      await tester.scrollUntilVisible(monthlyPlanButtonFinder, 50.0);
      expect(monthlyPlanButtonFinder, findsOneWidget);

      await tester.tap(monthlyPlanButtonFinder);
      await tester.pumpAndSettle();

      // --- SIMULADOR DE COMPRA ---
      expect(find.byType(AlertDialog), findsOneWidget);
      print("Teste: Simulador de Compra aberto.");

      final successButtonFinder = find.text('SUCESSO');
      expect(successButtonFinder, findsOneWidget);

      await tester.tap(successButtonFinder);
      await tester.pumpAndSettle();

      // --- VERIFICAÇÃO FINAL ---
      expect(find.byType(SubscriptionSelectionPage), findsNothing);
      expect(find.byType(AnimatedPremiumButton), findsNothing);
      expect(find.byType(AnimatedInfinityIcon), findsOneWidget);
      print("Teste: UI atualizada para o estado Premium com sucesso!");

      // A verificação bônus pode ser removida por enquanto para simplificar o teste
    });
  });
}
