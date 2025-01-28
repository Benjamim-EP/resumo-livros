import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AuthorPageLoadingPlaceholder extends StatelessWidget {
  const AuthorPageLoadingPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Placeholder para a capa do autor
        Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          child: Container(
            height: 200,
            color: Colors.grey,
            margin: const EdgeInsets.only(bottom: 16.0),
          ),
        ),
        // Placeholder para a descrição do autor
        Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          child: Container(
            height: 50,
            width: double.infinity,
            color: Colors.grey,
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
        ),
        // Placeholder para os botões de seleção
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[600]!,
              child: Container(
                height: 40,
                width: 80,
                color: Colors.grey,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // Placeholder para a lista de livros
        Expanded(
          child: ListView.builder(
            itemCount: 6, // Simula 6 itens carregando
            itemBuilder: (context, index) {
              return Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[600]!,
                child: Container(
                  height: 120,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
