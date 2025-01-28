import 'package:flutter/material.dart';

class TopicTitle extends StatelessWidget {
  final String title;

  const TopicTitle({required this.title, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontFamily: 'Abel',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
