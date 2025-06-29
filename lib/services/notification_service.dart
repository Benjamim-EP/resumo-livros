// lib/services/notification_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
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
      'Lembretes Devocionais',
      channelDescription:
          'Notificações para lembrar da leitura devocional diária.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    // --- CÓDIGO DE PRODUÇÃO ATIVADO ---
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Sua Leitura da Manhã',
      'Reserve um momento para seu devocional matutino.',
      _nextInstanceOfTime(8, 0), // Agenda para 8:00 AM
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repete todo dia nesse horário
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      1,
      'Sua Leitura da Noite',
      'Finalize seu dia com uma reflexão devocional.',
      _nextInstanceOfTime(20, 0), // Agenda para 20:00 (8 PM)
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    print("Notificações diárias de devocional agendadas para 8:00 e 20:00.");
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
