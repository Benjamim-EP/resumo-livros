import 'package:flutter/material.dart';
import '../avatar/author_image.dart';
import 'progress_indicator.dart';
import 'author_details.dart';
import 'rating_and_reviews.dart';

class AuthorFrame extends StatelessWidget {
  const AuthorFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 128, // Limita a largura do frame
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthorImage(),
          SizedBox(height: 4),
          ProgressIndicatorWidget(),
          SizedBox(height: 4),
          AuthorDetails(),
          SizedBox(height: 8),
          RatingAndReviews(),
        ],
      ),
    );
  }
}
