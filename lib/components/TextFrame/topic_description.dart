import 'package:flutter/material.dart';

class TopicDescription extends StatelessWidget {
  final String description;

  const TopicDescription({required this.description, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      style: const TextStyle(
        color: Color(0xFFEAF4F4),
        fontSize: 14,
        fontFamily: 'Abel',
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
