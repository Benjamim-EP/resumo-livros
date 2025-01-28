import 'package:flutter/material.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  const ProgressIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFF57596C),
        borderRadius: BorderRadius.circular(64),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 90,
          height: 11,
          decoration: BoxDecoration(
            color: const Color(0xFFCDE7BE),
            borderRadius: BorderRadius.circular(64),
          ),
        ),
      ),
    );
  }
}
