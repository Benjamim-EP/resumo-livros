// lib/app_initialization.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
// Importe o plugin de anúncios se for usá-lo aqui
// import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppInitialization {
  static Future<void> init() async {
    try {
      // Tenta inicializar o Firebase normalmente.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("AppInitialization: Firebase inicializado com sucesso.");
    } on FirebaseException catch (e) {
      // Se a inicialização falhar, verificamos se o erro é de "app duplicado".
      if (e.code == 'duplicate-app') {
        // Se for, significa que outro plugin (provavelmente o de anúncios)
        // já inicializou o Firebase. Isso não é um erro real para nós.
        print(
            "AppInitialization: A instância padrão do Firebase já existia (detectado via exceção).");
      } else {
        // Se for qualquer outro erro do Firebase, ele é um problema real e deve ser lançado.
        print(
            "AppInitialization: Erro INESPERADO do Firebase durante a inicialização: ${e.code} - ${e.message}");
        rethrow;
      }
    } catch (e) {
      // Captura outros erros não relacionados ao Firebase.
      print("AppInitialization: Erro GERAL durante a inicialização: $e");
      rethrow;
    }

    // <<< FIM DA CORREÇÃO DEFINITIVA >>>

    // Agora, com o Firebase garantidamente inicializado, podemos configurar
    // outros serviços que dependem dele.
    if (!kIsWeb) {
      // Como o google_mobile_ads pode ter inicializado o Firebase,
      // a inicialização do próprio SDK de anúncios deve vir DEPOIS.
      // Exemplo:
      // MobileAds.instance.initialize();
      // print("Mobile Ads SDK inicializado.");
    }
  }
}
