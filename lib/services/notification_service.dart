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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:septima_biblia/models/devotional_model.dart';

import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("FCM Background: Recebida mensagem com ID: ${message.messageId}");
  // Aqui você pode fazer processamento em background se necessário no futuro.
}

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ===================================
  // <<< INÍCIO DA NOVA SEÇÃO >>>
  // ===================================
  // Chave para salvar a preferência do usuário no SharedPreferences.
  // Sendo estática, pode ser acessada de outras partes do app (como a UserSettingsPage).
  static const String notificationsEnabledKey = 'notifications_enabled';
  // ===================================
  // <<< FIM DA NOVA SEÇÃO >>>
  // ===================================

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
    await _fcm.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('FCM Foreground: Mensagem recebida!');
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('FCM onMessageOpenedApp: O app foi aberto pela notificação.');
      _handleNotificationClick(message.data);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

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
            'community_channel',
            'Comunidade',
            channelDescription: 'Notificações de amigos e interações.',
            icon: 'icon',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  Future<void> saveFcmTokenToFirestore(String userId) async {
    try {
      String? token = await _fcm.getToken();
      if (token == null) {
        print("FCM: Não foi possível obter o token do dispositivo.");
        return;
      }
      print("FCM Token do Dispositivo: $token");

      final firestoreService = FirestoreService();
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

  void _handleNotificationClick(Map<String, dynamic> data) {
    final String? screen = data['screen'];
    if (screen != null) {
      print("Navegando para a tela: $screen");
      navigatorKey.currentState?.pushNamed(screen);
      if (data['type'] == 'friend_request') {
        Future.delayed(const Duration(milliseconds: 500), () {
          store.dispatch(LoadFriendsDataAction());
        });
      }
    }
  }

  Future<Map<String, String>?> _getRandomVerse() async {
    try {
      final String abbrevMapString = await rootBundle
          .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
      final Map<String, dynamic> booksMap = json.decode(abbrevMapString);
      final List<String> bookKeys = booksMap.keys.toList();
      if (bookKeys.isEmpty) return null;

      final random = Random();
      final String randomBookAbbrev = bookKeys[random.nextInt(bookKeys.length)];
      final bookData = booksMap[randomBookAbbrev];
      final String bookName = bookData['nome'];
      final int totalChapters = bookData['capitulos'];
      if (totalChapters <= 0) return null;

      final int randomChapterNum = (1 + random.nextInt(totalChapters));

      final String chapterJsonString = await rootBundle.loadString(
          'assets/Biblia/completa_traducoes/nvi/$randomBookAbbrev/$randomChapterNum.json');
      final List<dynamic> verses = json.decode(chapterJsonString);
      if (verses.isEmpty) return null;

      final int randomVerseIndex = random.nextInt(verses.length);
      final String verseText = verses[randomVerseIndex];
      final int verseNumber = randomVerseIndex + 1;

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

  // ===================================
  // <<< MÉTODO PRINCIPAL ATUALIZADO >>>
  // ===================================
  /// Agenda as notificações diárias para os devocionais, SE estiverem ativadas.
  Future<void> scheduleDailyDevotionals() async {
    // 1. Verifica a preferência do usuário ANTES de fazer qualquer coisa.
    final prefs = await SharedPreferences.getInstance();
    // O padrão é 'true' (ativado) para novos usuários.
    final bool areNotificationsEnabled =
        prefs.getBool(notificationsEnabledKey) ?? true;

    if (!areNotificationsEnabled) {
      print(
          "NotificationService: Agendamento ignorado pois as notificações estão desativadas pelo usuário.");
      // Garante que não haja notificações agendadas se a configuração estiver desativada.
      await cancelAllNotifications();
      return;
    }

    // 2. O resto da sua lógica de agendamento continua aqui.
    if (kIsIntegrationTest) {
      print(
          "NotificationService: Modo de teste de integração. Agendamento pulado.");
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
      'Lembretes Diários',
      channelDescription: 'Notificações diárias com devocionais e versículos.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    // --- NOTIFICAÇÃO 1: DEVOCIONAL DA MANHÃ (6:00) ---
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Sua Leitura da Manhã',
      'Reserve um momento para seu devocional matutino.',
      _nextInstanceOfTime(6, 0),
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
      final String verseReference = randomVerse['reference']!;
      final String verseText = randomVerse['text']!;
      final BigTextStyleInformation bigTextStyleInformation =
          BigTextStyleInformation(
        verseText,
        htmlFormatBigText: false,
        contentTitle: verseReference,
        summaryText: 'Versículo do Dia',
      );
      final AndroidNotificationDetails androidVerseNotificationDetails =
          AndroidNotificationDetails(
        'verse_of_the_day_channel_id',
        'Versículo do Dia',
        channelDescription:
            'Uma notificação diária com um versículo da Bíblia.',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: bigTextStyleInformation,
      );
      final NotificationDetails verseNotificationDetails =
          NotificationDetails(android: androidVerseNotificationDetails);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        2,
        verseReference,
        verseText,
        _nextInstanceOfTime(8, 0),
        verseNotificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print("Notificação do versículo do dia agendada para 8:00.");
    }

    // --- NOTIFICAÇÃO 3: DEVOCIONAL DA NOITE (20:00) ---
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1,
      'Sua Leitura da Noite',
      'Finalize seu dia com uma reflexão devocional.',
      _nextInstanceOfTime(20, 0),
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

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print("Todas as notificações foram canceladas.");
  }
}
