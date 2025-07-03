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

    signInWithGoogle(context).then((user) {
      // O 'then' aqui é apenas para o caso de o usuário cancelar o login
      // ou se houver um erro antes do Firebase sequer responder.
      // Se isso acontecer, podemos parar o indicador de loading.
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      // Se o login for bem-sucedido, o AuthCheck cuidará da navegação e
      // esta página será destruída, então não precisamos mais nos preocupar com o _isLoading.
    }).catchError((e) {
      // Trata erros que possam ocorrer na chamada inicial do signInWithGoogle
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFCDE7BE),
        body: SingleChildScrollView(
          // Adicionando o corpo para ser completo
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
                      child: Text('Login',
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text('Use sua conta Google para acessar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFFB0B0B0), fontSize: 16)),
                    ),
                    const SizedBox(height: 120),
                    const Center(
                      child: Text('Conecte-se com',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFFB0B0B0))),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 42,
                              height: 42,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue)),
                            )
                          : SvgPicture.asset('assets/icons/google.svg',
                              width: 42, height: 42),
                    ),
                    const SizedBox(height: 150),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
