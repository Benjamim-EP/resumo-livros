// integration_test/bible_reading_flow_test.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:septima_biblia/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/pages/biblie_page/section_item_widget.dart';
import 'package:percent_indicator/percent_indicator.dart'; // Para encontrar os indicadores de progresso

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  const String host = '192.168.1.58'; // Use o seu IP local aqui
  const int firestorePort = 8080;
  const int authPort = 9099;

  group('Fluxo de Leitura da Bíblia', () {
    setUpAll(() async {
      await Firebase.initializeApp();
      await FirebaseAuth.instance.useAuthEmulator(host, authPort);
      FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
      print("Firebase configurado para usar os emuladores locais.");

      // Cria e loga um usuário de teste para este grupo de testes
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      final testEmail =
          "bible-reader-${DateTime.now().millisecondsSinceEpoch}@test.com";
      await auth.createUserWithEmailAndPassword(
          email: testEmail, password: "password123");
      print("Usuário de teste para leitura da Bíblia criado e logado.");
    });

    testWidgets(
        'deve navegar entre capítulos, marcar progresso e refletir na página de usuário',
        (WidgetTester tester) async {
      // --- ETAPA 1: INICIAR O APP ---
      app.main();
      // Espera o app carregar e o AuthCheck processar o login
      await tester.pumpAndSettle(const Duration(seconds: 15));
      print("Teste: App iniciado e usuário logado.");

      // --- ETAPA 2: NAVEGAR PARA A ABA BÍBLIA ---
      final bibleTabFinder = find.byIcon(Icons.book_outlined);
      expect(bibleTabFinder, findsOneWidget);

      await tester.tap(bibleTabFinder);
      await tester.pumpAndSettle();
      print("Teste: Navegou para a aba Bíblia.");

      // --- ETAPA 3: VERIFICAR ESTADO INICIAL (GÊNESIS 1) ---
      // A AppBar deve conter o título do capítulo
      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('Gênesis 1')),
          findsOneWidget);
      print("Teste: Gênesis 1 carregado corretamente.");

      // --- ETAPA 4: NAVEGAR PARA O PRÓXIMO CAPÍTULO ---
      final nextChapterButtonFinder = find.byIcon(Icons.chevron_right);
      expect(nextChapterButtonFinder, findsOneWidget);

      await tester.tap(nextChapterButtonFinder);
      await tester.pumpAndSettle(const Duration(
          seconds: 3)); // Dê um tempo para o novo capítulo carregar
      print("Teste: Clicou para ir para o próximo capítulo.");

      // --- ETAPA 5: VERIFICAR NAVEGAÇÃO (GÊNESIS 2) ---
      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('Gênesis 2')),
          findsOneWidget);
      print("Teste: Gênesis 2 carregado corretamente.");

      // --- ETAPA 6: MARCAR A PRIMEIRA SEÇÃO COMO LIDA ---
      // Encontra o primeiro widget de seção e o botão "Marcar como Lido" dentro dele
      final firstSectionFinder = find.byType(SectionItemWidget).first;
      final markAsReadButtonFinder = find.descendant(
        of: firstSectionFinder,
        matching: find.widgetWithText(InkWell, 'Marcar como Lido'),
      );
      expect(markAsReadButtonFinder, findsOneWidget,
          reason: "Botão 'Marcar como Lido' não encontrado.");

      await tester.tap(markAsReadButtonFinder);
      await tester.pumpAndSettle();
      print("Teste: Marcou a primeira seção de Gênesis 2 como lida.");

      // --- ETAPA 7: VERIFICAR MUDANÇA NA UI ---
      // O botão agora deve ter o texto "Lido"
      final readButtonFinder = find.descendant(
        of: firstSectionFinder,
        matching: find.widgetWithText(InkWell, 'Lido'),
      );
      expect(readButtonFinder, findsOneWidget,
          reason: "O botão não mudou para 'Lido'.");
      print("Teste: UI da seção atualizada para 'Lido'.");

      // --- ETAPA 8: NAVEGAR PARA A ABA USUÁRIO ---
      final userTabFinder = find.byIcon(Icons.account_circle);
      expect(userTabFinder, findsOneWidget);

      await tester.tap(userTabFinder);
      await tester.pumpAndSettle(const Duration(
          seconds:
              5)); // Dê um tempo para a página de usuário carregar os dados
      print("Teste: Navegou para a aba Usuário.");

      // --- ETAPA 9: VERIFICAR O PROGRESSO ---
      print(
          "Teste: Verificando se os dados de progresso foram atualizados na UserPage...");

      // A verificação mais robusta é encontrar um widget específico que só aparece
      // quando há dados de progresso, como o Card principal.
      final progressCardTitleFinder = find.text("Progresso Geral da Bíblia");

      // Espera explicitamente por este widget aparecer, com um timeout.
      await tester
          .pumpAndSettle(const Duration(seconds: 5)); // Dê um tempo extra

      expect(progressCardTitleFinder, findsOneWidget,
          reason: "O card de progresso não foi encontrado na UserPage.");

      // Agora que sabemos que o card está na tela, podemos encontrar o indicador
      final circularProgressFinder = find.byType(CircularPercentIndicator);
      expect(circularProgressFinder, findsOneWidget);

      final CircularPercentIndicator progressIndicator =
          tester.widget(circularProgressFinder);
      expect(progressIndicator.percent, greaterThan(0.0),
          reason: "O progresso geral não aumentou após marcar uma seção.");

      print("Teste: Progresso geral na UserPage foi atualizado com sucesso!");
    });
  });
}
