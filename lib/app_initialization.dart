import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart'; // REMOVIDO
import 'package:resumo_dos_deuses_flutter/consts.dart';
import 'firebase_options.dart';
// import 'package:startapp_sdk/startapp.dart'; // Adicione se for chamar StartAppSdk().setTestAdsEnabled(true) aqui

class AppInitialization {
  static Future<void> init() async {
    await Firebase.initializeApp(
      name:
          "resumo-livros", // Certifique-se que este nome é intencional e consistente se você tiver múltiplos projetos Firebase. Se não, pode remover o parâmetro `name`.
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Stripe.publishableKey = stripePublishableKey;
    // MobileAds.instance.initialize(); // REMOVIDO - Esta era a inicialização do AdMob

    // A documentação do Start.io sugere que a inicialização principal ocorre
    // através das configurações no AndroidManifest.xml e Info.plist.
    // A chamada `StartAppSdk().setTestAdsEnabled(true)` é para habilitar anúncios de teste.
    // Você pode colocar essa chamada aqui ou no initState do seu widget MyApp.
    // Se você não precisar fazer nada assíncrono específico do Start.io aqui,
    // esta função pode até não precisar de alterações relacionadas a ele,
    // e a configuração de anúncios de teste pode ir para AdHelperStartIo ou MyApp.

    // Exemplo de como poderia ser, SE você quiser centralizar aqui:
    // final startAppSdk = StartAppSdk();
    // startAppSdk.setTestAdsEnabled(true); // Lembre-se de remover para produção
    // print("Start.io Test Ads Enabled via AppInitialization.init()");
  }
}
