import 'package:flutter/material.dart';

class SidebarIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalItems;

  const SidebarIndicator({
    super.key,
    required this.currentIndex,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final usableHeight = MediaQuery.of(context).size.height - 32.0;
    final position = (usableHeight / totalItems) * currentIndex;

    return Positioned(
      left: 8.0,
      top: 16.0,
      bottom: 16.0,
      child: Container(
        width: 4.0,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Stack(
          children: [
            Positioned(
              top: position,
              child: Container(
                width: 4.0,
                height: 20.0,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
