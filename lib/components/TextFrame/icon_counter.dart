import 'package:flutter/material.dart';

class IconCounter extends StatelessWidget {
  final int count;
  final Color backgroundColor;

  const IconCounter(
      {required this.count, required this.backgroundColor, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 33.5,
      height: 14.5,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Container(
              width: 15,
              height: 14.5,
              color: backgroundColor,
            ),
          ),
          Positioned(
            left: 18.5,
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Color(0xFF939999),
                fontSize: 12,
                fontFamily: 'SF Pro Text',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
