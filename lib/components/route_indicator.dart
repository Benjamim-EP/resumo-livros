import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RouteIndicator extends StatefulWidget {
  const RouteIndicator({super.key});

  @override
  _RouteIndicatorState createState() => _RouteIndicatorState();
}

class _RouteIndicatorState extends State<RouteIndicator> {
  bool _isVisible = true; // Controla a visibilidade dos ícones
  final List<Widget> _icons = [];

  void addRouteIcon(String assetPath) {
    setState(() {
      _icons.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: SvgPicture.asset(
            assetPath,
            width: 40,
            height: 40,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _isVisible,
      child: Positioned(
        bottom: 16,
        left: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botão para esconder ou mostrar os ícones
            GestureDetector(
              onTap: () {
                setState(() {
                  _isVisible = !_isVisible;
                });
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green,
                child: Icon(
                  _isVisible ? Icons.close : Icons.visibility,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._icons,
          ],
        ),
      ),
    );
  }
}
