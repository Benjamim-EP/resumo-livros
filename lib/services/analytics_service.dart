// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver getAnalyticsObserver() =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> setPremiumStatus(bool isPremium) async {
    await _analytics.setUserProperty(
        name: 'is_premium', value: isPremium.toString());
  }

  Future<void> setAppTheme(String themeName) async {
    await _analytics.setUserProperty(name: 'app_theme', value: themeName);
  }

  Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  Future<void> setUserProperty(
      {required String name, required String? value}) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // ✅ NOVO MÉTODO ADICIONADO AQUI
  /// Evento para quando um novo usuário se cadastra.
  Future<void> logSignUp(String signUpMethod) async {
    await _analytics.logSignUp(signUpMethod: signUpMethod);
  }

  Future<void> logLogout() async {
    await _analytics.logEvent(name: 'logout');
  }

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logBeginCheckout(String productId, double value) async {
    await _analytics.logBeginCheckout(
      value: value,
      currency: 'BRL',
      items: [
        AnalyticsEventItem(
          itemId: productId,
          itemName: productId,
        )
      ],
    );
  }

  Future<void> logPurchase(String productId, double value) async {
    await _analytics.logPurchase(
      value: value,
      currency: 'BRL',
      transactionId: '${DateTime.now().millisecondsSinceEpoch}',
    );
    await setPremiumStatus(true);
  }

  Future<void> logSearch(String searchTerm, String type) async {
    await _analytics
        .logSearch(searchTerm: searchTerm, parameters: {'search_type': type});
  }

  Future<void> logSectionRead(
      String book, int chapter, String sectionId) async {
    await _analytics.logEvent(
      name: 'section_read',
      parameters: {
        'book_abbrev': book,
        'chapter_number': chapter,
        'section_id': sectionId,
      },
    );
  }

  Future<void> logPremiumFeatureImpression(String featureName) async {
    await _analytics.logEvent(
      name: 'premium_feature_impression',
      parameters: {
        'feature_name':
            featureName, // Ex: 'interlinear_study', 'library_highlight'
      },
    );
  }

  Future<void> logLibraryResourceOpened(String resourceTitle) async {
    await _analytics.logEvent(
      name: 'library_resource_opened',
      parameters: {
        'resource_title': resourceTitle,
      },
    );
  }

  Future<void> logTabSelected(String tabName) async {
    await _analytics.logEvent(
      name: 'main_tab_selected',
      parameters: {
        'tab_name': tabName,
      },
    );
  }

  Future<void> logEvent(
      {required String name, Map<String, Object>? parameters}) async {
    await _analytics.logEvent(
      name: name,
      parameters: parameters,
    );
  }
}
