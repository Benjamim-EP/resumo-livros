import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/components/icons/rating_stars.dart';
import 'reviews_count.dart';

class RatingAndReviews extends StatelessWidget {
  const RatingAndReviews({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 128, // Limita a largura do container de rating e reviews
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // Alinha dentro do limite
        children: [
          RatingStars(rating: 2.1),
          ReviewsCount(reviews: 48),
        ],
      ),
    );
  }
}
