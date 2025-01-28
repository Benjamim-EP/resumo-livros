import 'package:flutter/material.dart';

class IconText extends StatelessWidget {
  final IconData icon;
  final Color color;

  const IconText({required this.icon, required this.color, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: color,
        size: 16.67,
      ),
    );
  }
}
