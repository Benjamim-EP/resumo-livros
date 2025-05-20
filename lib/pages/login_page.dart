// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removido: import 'package:flutter_redux/flutter_redux.dart'; // Não é usado diretamente aqui
// Removido: import 'package:resumo_dos_deuses_flutter/redux/store.dart';   // Não é usado diretamente aqui
// Removido: import 'package:resumo_dos_deuses_flutter/redux/actions.dart';// Não é usado diretamente aqui
import 'package:flutter_svg/svg.dart';
import 'package:resumo_dos_deuses_flutter/main.dart'; // IMPORTAR PARA ACESSAR navigatorKey
import '../services/sign_in_google.dart';
import '../services/sign_email.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  // initState e outros métodos podem permanecer os mesmos se não usarem _auth ou CheckFirstLoginAction

  Future<void> _signInWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      if (mounted) {
        setState(() => _errorMessage = 'Por favor, preencha todos os campos.');
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      User? user = await signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        print(
            "LoginPage: Login com email bem-sucedido para: ${user.email}. Navegando para MainAppScreen.");
        // NAVEGAÇÃO DIRETA APÓS SUCESSO
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/mainAppScreen', (route) => false);
      } else {
        // Erro já tratado no catch ou dentro de signInWithEmail
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          // ... (tratamento de erro como antes)
          switch (e.code) {
            case 'invalid-email':
            case 'INVALID_LOGIN_CREDENTIALS':
              _errorMessage = 'Email ou senha inválidos.';
              break;
            case 'user-disabled':
              _errorMessage = 'Este usuário foi desabilitado.';
              break;
            default:
              _errorMessage =
                  'Erro no login: ${e.message ?? "Tente novamente."}';
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (mounted) {
      setState(() {
        _isGoogleLoading = true;
        _errorMessage = null;
      });
    }

    // Passar `context` para `signInWithGoogle` se ele ainda precisar para `ScaffoldMessenger`
    User? user = await signInWithGoogle(context);

    if (user != null) {
      print(
          "LoginPage: Login com Google bem-sucedido para: ${user.email}. Navegando para MainAppScreen.");
      // NAVEGAÇÃO DIRETA APÓS SUCESSO
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/mainAppScreen', (route) => false);
    } else {
      print("LoginPage: Login com Google falhou ou foi cancelado.");
      // signInWithGoogle já deve ter mostrado um SnackBar em caso de erro de autenticação.
      // Se foi apenas cancelamento, _errorMessage pode continuar null.
    }

    if (mounted) setState(() => _isGoogleLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI da LoginPage como na sua última versão)
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
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Ao fazer login, você concorda com nossos Termos e Política de Privacidade',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email, color: Colors.grey),
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                      labelText: 'Senha',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCDE7BE),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF181A1A)),
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 20,
                              color: Color(0xFF181A1A),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Ou Conecte-se com',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFB0B0B0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            width: 42,
                            height: 42,
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue),
                                ),
                              ),
                            ),
                          )
                        : SvgPicture.asset(
                            'assets/icons/google.svg',
                            width: 42,
                            height: 42,
                          ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () {
                      if (mounted) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text(
                      'Ainda não cadastrado?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
