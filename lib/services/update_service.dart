// lib/services/update_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  /// Ponto de entrada principal para a verificação de atualizações.
  /// Este método detecta o "flavor" do build e chama a lógica de atualização apropriada.
  Future<void> checkForUpdate(BuildContext context) async {
    // Detecta qual versão do app está rodando usando a flag do dart-define.
    const bool isPlayStoreBuild = bool.fromEnvironment('IS_PLAY_STORE');

    if (isPlayStoreBuild) {
      // Se for a versão da Play Store, chama o método de atualização in-app.
      await _checkForPlayStoreUpdate();
    } else {
      // Se for a versão do site, chama o método de atualização via Remote Config.
      await _checkForWebsiteUpdate(context);
    }
  }

  /// LÓGICA PARA A VERSÃO DA PLAY STORE (seu código original)
  /// Usa o pacote in_app_update para o fluxo de atualização nativo do Android.
  Future<void> _checkForPlayStoreUpdate() async {
    // A verificação de atualização da Play Store só funciona em modo de lançamento (Release).
    if (kReleaseMode) {
      print("UpdateService (PlayStore): Verificando atualizações...");
      try {
        final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

        if (updateInfo.updateAvailability ==
            UpdateAvailability.updateAvailable) {
          print(
              "UpdateService (PlayStore): Atualização encontrada. Iniciando fluxo flexível.");
          // Inicia o fluxo de atualização flexível, que baixa em segundo plano.
          await InAppUpdate.startFlexibleUpdate();

          // Uma vez baixado, o app pode ser reiniciado para aplicar a atualização.
          print(
              "UpdateService (PlayStore): Atualização baixada. Completando o processo...");
          await InAppUpdate.completeFlexibleUpdate();
        } else {
          print("UpdateService (PlayStore): Nenhuma atualização disponível.");
        }
      } catch (e) {
        print(
            "UpdateService (PlayStore): Erro ao verificar por atualizações: $e");
      }
    } else {
      print(
          "UpdateService (PlayStore): Verificação de atualização pulada (não está em modo Release).");
    }
  }

  /// LÓGICA PARA A VERSÃO DO SITE (APK DIRETO)
  /// Usa o Firebase Remote Config para saber se há uma nova versão.
  Future<void> _checkForWebsiteUpdate(BuildContext context) async {
    // Para a versão do site, podemos testar em modo Debug.
    print(
        "UpdateService (Website): Verificando atualizações via Remote Config...");
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Define configurações para buscar novos valores do servidor.
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval:
            const Duration(hours: 1), // Evita buscas excessivas
      ));

      await remoteConfig.fetchAndActivate();

      final latestVersionCode = remoteConfig.getInt('latest_version_code');
      final latestVersionName = remoteConfig.getString('latest_version_name');
      final downloadUrl = remoteConfig.getString('update_download_url');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);

      print(
          "UpdateService (Website): Versão Atual: $currentVersionCode, Versão Remota: $latestVersionCode");

      if (latestVersionCode > currentVersionCode) {
        if (context.mounted) {
          _showUpdateDialog(context, latestVersionName, downloadUrl);
        }
      } else {
        print("UpdateService (Website): Nenhuma atualização disponível.");
      }
    } catch (e) {
      print("UpdateService (Website): Erro ao verificar por atualizações: $e");
    }
  }

  /// Mostra o diálogo de atualização para a versão do site.
  void _showUpdateDialog(
      BuildContext context, String versionName, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Nova Versão Disponível!"),
        content: Text(
            "Uma nova versão ($versionName) do Septima Bíblia está disponível para download."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Mais Tarde"),
          ),
          FilledButton(
            onPressed: () async {
              final url = Uri.parse(downloadUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text("Atualizar Agora"),
          ),
        ],
      ),
    );
  }
}
