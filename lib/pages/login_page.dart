// Em: lib/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/sign_in_google.dart';

// 1. Converter para StatefulWidget
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 2. Adicionar uma variável de estado para o loading
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    // Evita múltiplos cliques enquanto já está carregando
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Chama a função de login. O AuthCheck cuidará da navegação.
      await signInWithGoogle(context);
    } catch (e) {
      // O erro já é tratado dentro de signInWithGoogle com um SnackBar,
      // mas podemos logar aqui se necessário.
      print("Erro capturado na LoginPage: $e");
    } finally {
      // 3. Garante que o estado de loading seja desativado, mesmo se o login
      // for cancelado ou falhar, e somente se o widget ainda estiver na tela.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCDE7BE),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF181A1A),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 23,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 90),
                  const Center(
                    child: Text(
                      'Login',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Use sua conta Google para acessar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 120),
                  const Center(
                    child: Text(
                      'Conecte-se com',
                      style: TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    // 4. Desabilita o botão enquanto carrega ou chama a função
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    // 5. Mostra o loader ou o ícone do Google
                    child: _isLoading
                        ? const SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : SvgPicture.asset(
                            'assets/icons/google.svg',
                            width: 42,
                            height: 42,
                          ),
                  ),
                  const SizedBox(height: 150),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
