// lib/services/tutorial_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

class TutorialService {
  static const String _mainTutorialShownKey = 'main_tutorial_shown_v1';

  final GlobalKey keyMudarTema = GlobalKey();
  final GlobalKey keyMoedas = GlobalKey();
  final GlobalKey keySejaPremium = GlobalKey();
  final GlobalKey keyAbaUsuario = GlobalKey();
  final GlobalKey keyAbaBiblia = GlobalKey();
  final GlobalKey keyAbaBiblioteca = GlobalKey();
  final GlobalKey keyAbaDiario = GlobalKey();

  Future<void> startMainTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    bool tutorialShown = prefs.getBool(_mainTutorialShownKey) ?? false;

    if (!tutorialShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context).startShowCase([
          keyMudarTema,
          keyMoedas,
          keySejaPremium,
          keyAbaUsuario,
          keyAbaBiblia,
          keyAbaBiblioteca,
          keyAbaDiario,
        ]);
        prefs.setBool(_mainTutorialShownKey, true);
      });
    }
  }

  Widget buildShowcase({
    required GlobalKey key,
    required Widget child,
    required String title,
    required String description,
    TooltipPosition? tooltipPosition,
  }) {
    return Showcase(
      key: key,
      title: title,
      description: description,
      tooltipPosition: tooltipPosition,
      child: child,
    );
  }

  BottomNavigationBarItem buildShowcasedBottomNavItem({
    required GlobalKey key,
    required IconData icon,
    required String label,
    required String description,
  }) {
    return BottomNavigationBarItem(
      icon: buildShowcase(
        key: key,
        title: label,
        description: description,
        tooltipPosition: TooltipPosition.top,
        child: Icon(icon),
      ),
      label: label,
    );
  }
}
