import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingBooksPlaceholder extends StatelessWidget {
  const LoadingBooksPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(3, (index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Feature Title Placeholder
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[700]!,
                  highlightColor: Colors.grey[500]!,
                  child: Container(
                    height: 20,
                    width: 150,
                    color: Colors.grey,
                  ),
                ),
              ),
              // Horizontal List Placeholder
              SizedBox(
                height: 250, // Altura para o placeholder
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey[700]!,
                        highlightColor: Colors.grey[500]!,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Book Cover Placeholder
                            Container(
                              height: 150,
                              width: 100,
                              color: Colors.grey,
                              margin: const EdgeInsets.only(bottom: 8.0),
                            ),
                            // Book Name Placeholder
                            Container(
                              height: 16,
                              width: 100,
                              color: Colors.grey,
                              margin: const EdgeInsets.only(bottom: 4.0),
                            ),
                            // Author Name Placeholder
                            Container(
                              height: 12,
                              width: 80,
                              color: Colors.grey,
                              margin: const EdgeInsets.only(bottom: 4.0),
                            ),
                            // Chapter Name Placeholder
                            Container(
                              height: 12,
                              width: 70,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
