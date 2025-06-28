// lib/services/notification_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();

    // >>>>> INÍCIO DA MODIFICAÇÃO <<<<<
    // Altere o nome do ícone aqui.
    // O nome 'launcher_icon' foi tirado do seu AndroidManifest.xml.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('icon');
    // >>>>> FIM DA MODIFICAÇÃO <<<<<

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

  // Callback para quando uma notificação é tocada.
  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint('Payload da notificação: $payload');
    }
    // Aqui você pode adicionar lógica de navegação se a notificação tiver um payload
    // Ex: Navegar para a página de devocionais.
  }

  // Callback para iOS < 10 quando a notificação é recebida com o app aberto.
  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    debugPrint('Notificação em primeiro plano no iOS antigo: $title');
  }

  /// Calcula a próxima ocorrência de uma hora/minuto específico.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Se o horário agendado já passou hoje, agenda para amanhã.
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Agenda as notificações diárias para os devocionais.
  Future<void> scheduleDailyDevotionals() async {
    // Solicita permissão no Android 13+
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted =
          await androidImplementation?.requestNotificationsPermission();
      if (granted == false) {
        print("Permissão de notificação negada pelo usuário.");
        return;
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

    // Notificação da Manhã (8:00 AM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // ID único para a notificação da manhã
      'Sua Leitura da Manhã',
      'Reserve um momento para seu devocional matutino.',
      _nextInstanceOfTime(8, 0),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repetir diariamente neste horário
    );

    // Notificação da Noite (20:00 / 8:00 PM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1, // ID único para a notificação da noite
      'Sua Leitura da Noite',
      'Finalize seu dia com uma reflexão devocional.',
      _nextInstanceOfTime(20, 0),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repetir diariamente neste horário
    );

    print("Notificações diárias de devocional agendadas para 8:00 e 20:00.");
  }

  /// **FUNÇÃO PARA TESTE**
  /// Agenda uma notificação para daqui a 5 segundos.
  Future<void> scheduleTestNotification() async {
    // A definição do canal ainda é necessária
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'test_channel', // ID do canal de teste
      'Notificações de Teste',
      channelDescription: 'Canal para notificações de teste imediato.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    // >>> MUDANÇA PRINCIPAL: Usamos .show() em vez de .zonedSchedule() <<<
    await flutterLocalNotificationsPlugin.show(
      99, // ID da notificação
      'Notificação de Teste Imediato',
      'Se você está vendo isso, o sistema de notificação funciona!',
      notificationDetails,
      payload: 'teste_imediato_payload', // Payload opcional
    );

    print("Notificação de TESTE disparada imediatamente com .show()");
  }

  /// Cancela todas as notificações agendadas.
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print("Todas as notificações foram canceladas.");
  }
}
