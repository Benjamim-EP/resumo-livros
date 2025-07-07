// lib/services/notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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

  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint('Payload da notificação: $payload');
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
