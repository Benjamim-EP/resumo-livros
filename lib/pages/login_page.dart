import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/services/auth_check.dart';
import '../services/sign_in_google.dart';
import '../services/sign_email.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage; // Para exibir mensagens de erro
  bool _isLoading = false; // Adiciona estado de carregamento

  @override
  void initState() {
    super.initState();
    _checkUserLoggedIn();
  }

  // Verifica se o usuário já está logado
  Future<void> _checkUserLoggedIn() async {
    User? user = _auth.currentUser;
    if (user != null) {
      StoreProvider.of<AppState>(context).dispatch(
        CheckFirstLoginAction(user.uid),
      );
    }
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, preencha todos os campos.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        final userId = user.uid;
        StoreProvider.of<AppState>(context).dispatch(
          CheckFirstLoginAction(userId),
        );
        store.dispatch(UpdateUserUidAction(user.uid));

        // Redireciona para o AuthCheck após o login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AuthCheck()),
        );
      } else {
        setState(() {
          _errorMessage =
              'Erro no login. Verifique suas credenciais ou tente novamente.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _errorMessage = 'O formato do email é inválido.';
            break;
          case 'user-not-found':
            _errorMessage = 'Usuário não encontrado. Verifique o email.';
            break;
          case 'wrong-password':
            _errorMessage = 'Senha incorreta. Verifique e tente novamente.';
            break;
          default:
            _errorMessage = 'Erro no login: ${e.message}';
            break;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro inesperado: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCDE7BE), // Cor do fundo
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Caixa com bordas arredondadas e sombra
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF181A1A), // Fundo escuro
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
                        color: Colors.white, // Texto claro para o fundo escuro
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Ao fazer login, você concorda com nossos Termos e Política de Privacidade',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB0B0B0), // Texto mais claro
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Input de email
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.email, // Ícone de email
                        color: Colors.grey,
                      ),
                      labelText: 'Email',
                      labelStyle: const TextStyle(
                        color: Colors.grey, // Cor do texto do label
                      ),
                      filled: true,
                      fillColor:
                          const Color(0xFFF2F2F2), // Cor clara para o fundo
                      enabledBorder: UnderlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.grey, // Linha inferior (borda) cinza
                        ),
                        borderRadius:
                            BorderRadius.circular(10), // Borda arredondada
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors
                              .blue, // Linha inferior (borda) azul quando focado
                        ),
                        borderRadius:
                            BorderRadius.circular(10), // Borda arredondada
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
// Input de senha
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.lock, // Ícone de senha (cadeado)
                        color: Colors.grey,
                      ),
                      labelText: 'Senha',
                      labelStyle: const TextStyle(
                        color: Colors.grey, // Cor do texto do label
                      ),
                      filled: true,
                      fillColor:
                          const Color(0xFFF2F2F2), // Cor clara para o fundo
                      enabledBorder: UnderlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors.grey, // Linha inferior (borda) cinza
                        ),
                        borderRadius:
                            BorderRadius.circular(10), // Borda arredondada
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: const BorderSide(
                          color: Colors
                              .blue, // Linha inferior (borda) azul quando focado
                        ),
                        borderRadius:
                            BorderRadius.circular(10), // Borda arredondada
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Botão de login
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null // Desativa o botão enquanto carrega
                        : _signInWithEmail,
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
                              color: Color.fromARGB(255, 71, 172, 172),
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

// Exibe a mensagem de erro, se houver
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
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
                  // Botão circular com ícone do Google
                  ElevatedButton(
                    onPressed: () => signInWithGoogle(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, // Fundo branco
                      shape: const CircleBorder(), // Forma circular
                      padding: const EdgeInsets.all(16), // Tamanho do botão
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/google.svg', // Caminho para o arquivo SVG
                      width: 42,
                      height: 42,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Redirecionamento para cadastro
                  GestureDetector(
                    onTap: () {
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
