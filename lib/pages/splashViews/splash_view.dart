import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashView extends StatefulWidget {
  final AnimationController animationController;

  const SplashView({Key? key, required this.animationController})
      : super(key: key);

  @override
  _SplashViewState createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  Widget build(BuildContext context) {
    final _introductionAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0.0, -1.0),
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: const Interval(
          0.0,
          0.2,
          curve: Curves.fastOutSlowIn,
        ),
      ),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SlideTransition(
      position: _introductionAnimation,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: screenHeight * 0.2), // Empurra os itens para baixo
            SizedBox(
              width: screenWidth,
              child: SvgPicture.asset(
                'assets/intro/entrada1.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Resumos Dinâmicos',
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
              'Leia de forma dinâmica o conteudo dos \nseus autores favoritos',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF8F8F8F),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Material(
                color: Colors.transparent, // Transparente para manter o estilo
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.0), // Arredondamento
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                      50.0), // Define o splash arredondado
                  onTap: () {
                    widget.animationController.animateTo(0.2);
                  },
                  child: Container(
                    height: 58,
                    width: screenWidth * 0.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50.0),
                      color: const Color(0xFF232538),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Próximo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFEAF4F4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
