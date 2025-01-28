import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  const RatingStars({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Geramos as estrelas com base no rating
        ...List.generate(5, (index) {
          if (index < rating.floor()) {
            // Estrela cheia
            return const Icon(Icons.star, color: Colors.amber, size: 14);
          } else if (index < rating && rating - index > 0) {
            // Estrela pela metade
            return const Icon(Icons.star_half, color: Colors.amber, size: 14);
          } else {
            // Estrela vazia (outline)
            return const Icon(Icons.star_border, color: Colors.amber, size: 14);
          }
        }),
        const SizedBox(width: 4),
        Text(
          rating.toString(),
          style: const TextStyle(
            color: Color(0xFFC4CCCC),
            fontSize: 14,
            fontFamily: 'Abel',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
