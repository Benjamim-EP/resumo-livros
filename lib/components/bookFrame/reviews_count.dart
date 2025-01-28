import 'package:flutter/material.dart';

class ReviewsCount extends StatelessWidget {
  final int reviews;
  const ReviewsCount({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 11.61,
        ),
        const SizedBox(width: 4),
        Text(
          reviews.toString(),
          style: const TextStyle(
            color: Color.fromARGB(255, 199, 0, 0),
            fontSize: 12,
            fontFamily: 'Abel',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
