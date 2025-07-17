// lib/services/notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:septima_biblia/main.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:septima_biblia/redux/actions.dart'; // ✅ NOVO IMPORT
import 'package:septima_biblia/redux/store.dart'; // ✅ NOVO IMPORT
import 'package:septima_biblia/services/firestore_service.dart'; // ✅ NOVO IMPORT

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("FCM Background: Recebida mensagem com ID: ${message.messageId}");
  // Aqui você pode fazer processamento em background se necessário no futuro.
}

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm =
      FirebaseMessaging.instance; // ✅ Adiciona instância do FCM

  Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    try {
      final String timeZoneName = 'America/Sao_Paulo';
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print("Erro ao definir o fuso horário: $e");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('icon');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    await _initFcm();
  }

  Future<void> _initFcm() async {
    // Solicita permissão no iOS e Android 13+
    await _fcm.requestPermission();

    // Configura os listeners de mensagens
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('FCM Foreground: Mensagem recebida!');
      print('Dados da Mensagem: ${message.data}');

      if (message.notification != null) {
        print('A mensagem contém uma notificação: ${message.notification}');
        // Mostra a notificação local para o usuário ver (quando o app está aberto)
        _showLocalNotification(message);
      }
    });

    // Listener para quando o usuário toca na notificação e abre o app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('FCM onMessageOpenedApp: O app foi aberto pela notificação.');
      _handleNotificationClick(message.data);
    });

    // Configura o handler para mensagens em background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // ✅ NOVA FUNÇÃO PARA EXIBIR A NOTIFICAÇÃO LOCAL
  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'community_channel', // Um novo canal para notificações da comunidade
            'Comunidade',
            channelDescription: 'Notificações de amigos e interações.',
            icon: 'icon', // Seu ícone de notificação
          ),
        ),
        payload: jsonEncode(message.data), // Passa os dados para o clique
      );
    }
  }

  // ✅ NOVA FUNÇÃO PARA SALVAR O TOKEN
  Future<void> saveFcmTokenToFirestore(String userId) async {
    try {
      String? token = await _fcm.getToken();
      if (token == null) {
        print("FCM: Não foi possível obter o token do dispositivo.");
        return;
      }
      print("FCM Token do Dispositivo: $token");

      final firestoreService = FirestoreService();
      // Usando arrayUnion para adicionar o token sem duplicatas
      await firestoreService.updateUserField(
          userId, 'fcmTokens', FieldValue.arrayUnion([token]));
      print("FCM: Token salvo no Firestore para o usuário $userId.");
    } catch (e) {
      print("FCM: Erro ao salvar token no Firestore: $e");
    }
  }

  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    final String? payloadString = notificationResponse.payload;
    if (payloadString != null) {
      try {
        final Map<String, dynamic> payloadData = jsonDecode(payloadString);
        _handleNotificationClick(payloadData);
      } catch (e) {
        print("Erro ao decodificar payload da notificação local: $e");
      }
    }
  }

  // ✅ NOVA FUNÇÃO PARA LIDAR COM O CLIQUE NA NOTIFICAÇÃO
  void _handleNotificationClick(Map<String, dynamic> data) {
    final String? screen = data['screen'];
    if (screen != null) {
      print("Navegando para a tela: $screen");
      // Usa a chave global de navegação para navegar de qualquer lugar do app
      navigatorKey.currentState?.pushNamed(screen);

      // Se for um pedido de amizade, também pode ser útil recarregar os dados
      if (data['type'] == 'friend_request') {
        // Pequeno delay para dar tempo da tela carregar antes de despachar a ação
        Future.delayed(const Duration(milliseconds: 500), () {
          store.dispatch(LoadFriendsDataAction());
        });
      }
    }
  }

  Future<Map<String, String>?> _getRandomVerse() async {
    try {
      // 1. Carrega o mapa de livros
      final String abbrevMapString = await rootBundle
          .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
      final Map<String, dynamic> booksMap = json.decode(abbrevMapString);
      final List<String> bookKeys = booksMap.keys.toList();

      if (bookKeys.isEmpty) return null;

      // 2. Sorteia um livro
      final random = Random();
      final String randomBookAbbrev = bookKeys[random.nextInt(bookKeys.length)];
      final bookData = booksMap[randomBookAbbrev];
      final String bookName = bookData['nome'];
      final int totalChapters = bookData['capitulos'];

      if (totalChapters <= 0) return null;

      // 3. Sorteia um capítulo
      final int randomChapterNum = (1 + random.nextInt(totalChapters)) as int;

      // 4. Carrega o arquivo do capítulo para descobrir o número de versículos
      // Usaremos a NVI como padrão para as notificações
      final String chapterJsonString = await rootBundle.loadString(
          'assets/Biblia/completa_traducoes/nvi/$randomBookAbbrev/$randomChapterNum.json');
      final List<dynamic> verses = json.decode(chapterJsonString);

      if (verses.isEmpty) return null;

      // 5. Sorteia um versículo
      final int randomVerseIndex = random.nextInt(verses.length);
      final String verseText = verses[randomVerseIndex];
      final int verseNumber = randomVerseIndex + 1;

      // 6. Retorna o texto e a referência formatada
      return {
        'reference': '$bookName $randomChapterNum:$verseNumber',
        'text': verseText,
      };
    } catch (e) {
      print("Erro ao obter versículo aleatório: $e");
      return null;
    }
  }

  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    debugPrint('Notificação em primeiro plano no iOS antigo: $title');
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Agenda as notificações diárias para os devocionais.
  Future<void> scheduleDailyDevotionals() async {
    // A verificação de permissões permanece a mesma
    if (kIsIntegrationTest) {
      print(
          "NotificationService: Modo de teste de integração detectado. Pedido de permissão ignorado.");
      return;
    }
    if (Platform.isAndroid) {
      bool notificationsGranted = await _requestBasicNotificationPermission();
      if (!notificationsGranted) return;
      bool exactAlarmsGranted = await _requestExactAlarmPermission();
      if (!exactAlarmsGranted) {
        print(
            "Permissão de alarme exato não concedida. O agendamento pode não ser preciso.");
      }
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'devotional_channel_id',
      'Lembretes Diários', // Nome do canal mais genérico agora
      channelDescription: 'Notificações diárias com devocionais e versículos.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    // --- NOTIFICAÇÃO 1: DEVOCIONAL DA MANHÃ (6:00) ---
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // ID 0 para o devocional da manhã
      'Sua Leitura da Manhã',
      'Reserve um momento para seu devocional matutino.',
      _nextInstanceOfTime(6, 0), // <<< MUDANÇA: Horário alterado para 6:00 AM
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    print("Notificação do devocional da manhã agendada para 6:00.");

    // --- NOTIFICAÇÃO 2: VERSÍCULO DO DIA (8:00) ---
    final randomVerse = await _getRandomVerse();
    if (randomVerse != null) {
      // <<< INÍCIO DA MUDANÇA >>>

      // 1. Pega o texto e a referência do versículo
      final String verseReference = randomVerse['reference']!;
      final String verseText = randomVerse['text']!;

      // 2. Cria um estilo de notificação que permite texto longo
      final BigTextStyleInformation bigTextStyleInformation =
          BigTextStyleInformation(
        verseText, // O texto completo que será exibido quando a notificação for expandida
        htmlFormatBigText: false,
        contentTitle: verseReference, // O título que aparece no modo expandido
        summaryText: 'Versículo do Dia', // Um pequeno texto de sumário
      );

      // 3. Cria os detalhes da notificação para Android, agora com o novo estilo
      final AndroidNotificationDetails androidVerseNotificationDetails =
          AndroidNotificationDetails(
        'verse_of_the_day_channel_id', // Um ID de canal diferente é uma boa prática
        'Versículo do Dia',
        channelDescription:
            'Uma notificação diária com um versículo da Bíblia.',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: bigTextStyleInformation, // <<< APLICA O ESTILO AQUI
      );

      // 4. Junta os detalhes para todas as plataformas
      final NotificationDetails verseNotificationDetails =
          NotificationDetails(android: androidVerseNotificationDetails);

      // 5. Agenda a notificação usando os novos detalhes
      await flutterLocalNotificationsPlugin.zonedSchedule(
        2,
        verseReference,
        verseText, // O corpo da notificação (pode aparecer cortado no modo recolhido)
        _nextInstanceOfTime(8, 0),
        verseNotificationDetails, // <<< USA OS DETALHES ESPECÍFICOS AQUI
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print("Notificação do versículo do dia agendada para 8:00.");
    } else {
      print(
          "Não foi possível agendar o versículo do dia por falha ao obter o texto.");
    }

    // --- NOTIFICAÇÃO 3: DEVOCIONAL DA NOITE (20:00) ---
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1, // ID 1 (mantido) para o devocional da noite
      'Sua Leitura da Noite',
      'Finalize seu dia com uma reflexão devocional.',
      _nextInstanceOfTime(20, 0), // Horário mantido
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    print("Notificação do devocional da noite agendada para 20:00.");
  }

  Future<bool> _requestBasicNotificationPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted =
        await androidImplementation?.requestNotificationsPermission();
    if (granted == false) {
      print("Permissão de notificação (POST_NOTIFICATIONS) negada.");
    }
    return granted ?? false;
  }

  Future<bool> _requestExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isDenied) {
      final newStatus = await Permission.scheduleExactAlarm.request();
      return newStatus.isGranted;
    }
    return status.isGranted;
  }

  /// Função para teste imediato que pode ser mantida para depuração futura.
  Future<void> scheduleTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'test_channel',
      'Notificações de Teste',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      99,
      'Notificação de Teste Imediato',
      'Se você está vendo isso, o sistema de notificação funciona!',
      notificationDetails,
    );
    print("Notificação de TESTE disparada imediatamente com .show()");
  }

  /// Cancela todas as notificações agendadas.
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print("Todas as notificações foram canceladas.");
  }
}
