// lib/services/custom_notification_service.dart
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

class CustomNotificationService {
  // Notificação de SUCESSO (verde)
  static void showSuccess(BuildContext context, String message) {
    Flushbar(
      message: message,
      icon: Icon(
        Icons.check_circle_outline,
        size: 28.0,
        color: Colors.green.shade300,
      ),
      duration: const Duration(seconds: 3),
      leftBarIndicatorColor: Colors.green.shade300,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.all(8),
      flushbarStyle: FlushbarStyle.FLOATING,
      boxShadows: [
        BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8)
      ],
      backgroundColor: const Color(0xFF323232), // Cor escura
    ).show(context);
  }

  static void showInfo(BuildContext context, String message,
      {Duration duration = const Duration(seconds: 4)}) {
    if (!context.mounted) return; // Verificação de segurança

    Flushbar(
      message: message,
      icon: Icon(
        Icons.info_outline, // Ícone de informação
        size: 28.0,
        color: Colors.blue.shade300, // Cor azul para informação
      ),
      duration: duration,
      leftBarIndicatorColor: Colors.blue.shade300,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.all(8),
      flushbarStyle: FlushbarStyle.FLOATING,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          spreadRadius: 1,
          blurRadius: 8,
        )
      ],
      backgroundColor: const Color(0xFF323232), // Mesmo fundo escuro
    ).show(context);
  }

  // Notificação de ERRO (vermelha)
  static void showError(BuildContext context, String message) {
    Flushbar(
      message: message,
      icon: Icon(
        Icons.error_outline,
        size: 28.0,
        color: Colors.red.shade300,
      ),
      duration: const Duration(seconds: 4),
      leftBarIndicatorColor: Colors.red.shade300,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.all(8),
      flushbarStyle: FlushbarStyle.FLOATING,
      boxShadows: [
        BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8)
      ],
      backgroundColor: const Color(0xFF323232),
    ).show(context);
  }

  // Notificação de AVISO (amarela/laranja) com uma ação
  static void showWarningWithAction({
    required BuildContext context,
    required String message,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    Flushbar(
      title: "Moedas Insuficientes", // Título opcional
      message: message,
      icon: Icon(
        Icons.monetization_on_outlined,
        size: 28.0,
        color: Colors.amber.shade300,
      ),
      duration:
          const Duration(seconds: 5), // Duração maior para dar tempo de clicar
      leftBarIndicatorColor: Colors.amber.shade300,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.all(8),
      flushbarStyle: FlushbarStyle.FLOATING,
      boxShadows: [
        BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8)
      ],
      backgroundColor: const Color(0xFF323232),
      mainButton: TextButton(
        onPressed: onButtonPressed,
        child: Text(
          buttonText.toUpperCase(),
          style: TextStyle(
              color: Colors.amber.shade300, fontWeight: FontWeight.bold),
        ),
      ),
    ).show(context);
  }
}
