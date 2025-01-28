import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:resumo_dos_deuses_flutter/consts.dart';
import 'firebase_options.dart';

class AppInitialization {
  static Future<void> init() async {
    await Firebase.initializeApp(
      name: "resumo-livros",
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Stripe.publishableKey = stripePublishableKey;
    MobileAds.instance.initialize();
  }
}
