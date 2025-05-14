// lib/pages/signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar Firestore
import 'package:flutter_redux/flutter_redux.dart';
import '../redux/store.dart';
import '../redux/actions.dart';

class SignUpEmailPage extends StatefulWidget {
  const SignUpEmailPage({super.key}); // Adicionado super.key

  @override
  _SignUpEmailPageState createState() => _SignUpEmailPageState();
}

class _SignUpEmailPageState extends State<SignUpEmailPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signUp(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text);

      final User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());

        // Salvar informações adicionais no Firestore
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        Map<String, dynamic> newUserFirestoreData = {
          'userId': user.uid,
          'nome': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'photoURL': user.photoURL ?? '', // Pode ser null
          'dataCadastro': FieldValue.serverTimestamp(),
          'Dias': 0,
          'Livros': 0,
          'Tópicos': 0,
          'firstLogin': true, // Novo usuário, então é o primeiro login
          'selos': 10,
          'descrição': "",
          'Tribo': null,
          'userFeatures': {},
          'indicacoes': {},
          'topicSaves': {},
          'booksProgress': {},
          'lastReadBookAbbrev': null,
          'lastReadChapter': null,
          'isPremium': {'status': 'inactive', 'expiration': null},
          // NOVOS CAMPOS DE MOEDAS E ANÚNCIOS
          'userCoins': 100,
          'lastRewardedAdWatchTime': null,
          'rewardedAdsWatchedToday': 0,
          // NOVOS CAMPOS DE ASSINATURA
          'stripeCustomerId': null,
          'subscriptionStatus': 'inactive',
          'subscriptionEndDate': null,
          'stripeSubscriptionId': null,
          'activePriceId': null,
        };
        await userDocRef.set(newUserFirestoreData);
        print("Novo usuário (Email/Senha) criado no Firestore: ${user.uid}");

        final storeInstance =
            StoreProvider.of<AppState>(context, listen: false);
        storeInstance.dispatch(UserLoggedInAction(
          userId: user.uid,
          email: user.email!,
          nome: _nameController.text.trim(),
        ));
        storeInstance
            .dispatch(FirstLoginSuccessAction(true)); // É o primeiro login
        // Carrega os detalhes recém-criados para o estado Redux
        storeInstance.dispatch(UserDetailsLoadedAction(newUserFirestoreData));

        // Redireciona para a tela de formulário inicial
        Navigator.pushReplacementNamed(context, '/finalForm');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'weak-password') {
          _errorMessage = 'A senha fornecida é muito fraca.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'Este email já está em uso por outra conta.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'O email fornecido é inválido.';
        } else {
          _errorMessage = 'Erro ao criar conta: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocorreu um erro inesperado: $e';
      });
    } finally {
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 90),
                    const Center(
                      child: Text(
                        'Cadastro',
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
                        'Crie sua conta para acessar o aplicativo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    TextFormField(
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira seu nome';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        prefixIcon:
                            const Icon(Icons.person, color: Colors.grey),
                        labelText: 'Nome Completo',
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
                    TextFormField(
                      controller: _emailController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira um email';
                        } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                            .hasMatch(value)) {
                          return 'Por favor, insira um email válido';
                        }
                        return null;
                      },
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
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira uma senha';
                        } else if (value.length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres';
                        }
                        return null;
                      },
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
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(
                        height: 36), // Ajustado para dar espaço ao erro
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _signUp(context),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF181A1A)),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Cadastrar',
                              style: TextStyle(
                                fontSize: 20,
                                color: Color(0xFF181A1A),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Volta para a tela de login
                      },
                      child: const Text(
                        'Já tem uma conta? Faça Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30), // Espaço extra no final
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
