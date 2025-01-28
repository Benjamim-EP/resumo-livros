import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class MoodDiaryVew extends StatelessWidget {
  final AnimationController animationController;

  const MoodDiaryVew({Key? key, required this.animationController})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final svgWidth = screenWidth * 0.9;
    final image1Size = svgWidth * 0.5;
    final image2Size = svgWidth * 0.6;
    final textFontSize = screenWidth * 0.03;
    final _firstHalfAnimation =
        Tween<Offset>(begin: Offset(1, 0), end: Offset(0, 0))
            .animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(
        0.2,
        0.4,
        curve: Curves.fastOutSlowIn,
      ),
    ));
    final secondHalfAnimation =
        Tween<Offset>(begin: const Offset(0, 0), end: const Offset(-1, 0))
            .animate(CurvedAnimation(
      parent: animationController,
      curve: const Interval(
        0.6,
        0.8,
        curve: Curves.fastOutSlowIn,
      ),
    ));

    return SlideTransition(
      position: _firstHalfAnimation,
      child: SlideTransition(
        position: secondHalfAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: screenHeight * 0.12),
                  SizedBox(
                    width: svgWidth,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Renderizando o SVG
                        SvgPicture.asset(
                          'assets/intro/entrada3.svg',
                          fit: BoxFit.contain,
                        ),
                        // Primeira imagem

                        Positioned(
                          left: svgWidth * 0.28,
                          top: svgWidth * 0.01,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(image1Size * 0.5),
                            child: Image.asset(
                              'assets/intro/C.S. Lewis.webp',
                              width: image1Size * 0.8,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Chat com Autor',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color.fromRGBO(234, 244, 244, 1),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sistema de conversação com autores \ncom base na sua literatura',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF8F8F8F),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
