// lib/services/update_service.dart
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  Future<void> checkForUpdate() async {
    // A verificação de atualização só funciona em modo release,
    // e não adianta rodar no emulador ou em modo debug.
    if (kReleaseMode) {
      print("UpdateService: Verificando atualizações (modo Release)...");
      try {
        final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

        // Verifica se uma atualização está disponível
        if (updateInfo.updateAvailability ==
            UpdateAvailability.updateAvailable) {
          print(
              "UpdateService: Atualização encontrada. Iniciando fluxo de atualização flexível.");
          // Inicia o fluxo de atualização flexível
          await InAppUpdate.startFlexibleUpdate();

          // Após o download ser concluído em segundo plano,
          // o app pode ser reiniciado para aplicar a atualização.
          print(
              "UpdateService: Atualização baixada. Completando o processo...");
          await InAppUpdate.completeFlexibleUpdate();
        } else {
          print("UpdateService: Nenhuma atualização disponível.");
        }
      } catch (e) {
        print("UpdateService: Erro ao verificar por atualizações: $e");
      }
    } else {
      print(
          "UpdateService: Verificação de atualização pulada (não está em modo Release).");
    }
  }
}
