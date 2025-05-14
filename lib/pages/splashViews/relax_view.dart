import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RelaxView extends StatelessWidget {
  final AnimationController animationController;

  const RelaxView({super.key, required this.animationController});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final svgWidth = screenWidth * 0.9;
    final image1Size = svgWidth * 0.5;
    final image2Size = svgWidth * 0.6;
    final textFontSize = screenWidth * 0.03;

    final firstHalfAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: const Offset(0, 0))
            .animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.2, curve: Curves.fastOutSlowIn),
      ),
    );

    final secondHalfAnimation =
        Tween<Offset>(begin: const Offset(0, 0), end: const Offset(-1, 0))
            .animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.2, 0.4, curve: Curves.fastOutSlowIn),
      ),
    );

    return SlideTransition(
      position: firstHalfAnimation,
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
                      children: [
                        // Renderizando o SVG
                        SvgPicture.asset(
                          'assets/intro/entrada2.svg',
                          fit: BoxFit.contain,
                        ),
                        // Primeira imagem
                        Positioned(
                          left: svgWidth * 0.43,
                          top: -image1Size * 0.3,
                          child: Image.asset(
                            'assets/intro/Kierkergaard2.webp',
                            width: image1Size * 1.1,
                          ),
                        ),
                        // Segunda imagem
                        Positioned(
                          left: svgWidth * 0.05,
                          top: svgWidth * 0.04,
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
                        // Terceira imagem
                        Positioned(
                          left: svgWidth * 0.22,
                          top: screenHeight * 0.325,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(image2Size * 0.5),
                            child: Image.asset(
                              'assets/intro/Billy Graham2.webp',
                              width: image2Size,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Texto
                        Positioned(
                          left: svgWidth * 0.32,
                          top: screenHeight * 0.28,
                          child: Text(
                            "CONDIÇÃO HUMANA E\nO DESEJO DE SENTIDO",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: textFontSize,
                              color: const Color(0xFF181A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sistema de Rotas',
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
                    'Rotas para os principais temas literários,\n que unem a literatura e conceitos de\ndiversos autores com o sistema de rotas',
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
