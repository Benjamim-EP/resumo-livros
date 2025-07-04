// Crie um novo arquivo ou adicione a uma classe de helpers/services existente
// Ex: lib/services/subscription_manager.dart

import 'package:url_launcher/url_launcher.dart';

class SubscriptionManager {
  static Future<void> openSubscriptionManagement(
      String productId, String packageName) async {
    // Constrói a URL específica para gerenciar a assinatura
    final url = Uri.parse(
      'https://play.google.com/store/account/subscriptions?sku=$productId&package=$packageName',
    );

    // Tenta abrir a URL. Se não conseguir, lança uma exceção.
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Como fallback, abre a página geral de assinaturas se a específica falhar
      final fallbackUrl =
          Uri.parse('https://play.google.com/store/account/subscriptions');
      if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir a central de assinaturas da Google Play.';
      }
    }
  }
}
