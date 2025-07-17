// lib/pages/community/find_friends_page.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/community/public_profile_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class FindFriendsPage extends StatefulWidget {
  const FindFriendsPage({super.key});

  @override
  State<FindFriendsPage> createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: "southamerica-east1");

  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;

  Future<void> _searchUser() async {
    final septimaId = _searchController.text.trim();
    if (septimaId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundUser = null;
    });

    try {
      final callable = _functions.httpsCallable('findUserBySeptimaId');
      final result =
          await callable.call<Map<String, dynamic>>({'septimaId': septimaId});

      print(
          "FindFriendsPage: Resposta recebida da Cloud Function: ${result.data}");

      if (mounted) {
        final responseData = result.data;

        // ✅ INÍCIO DA CORREÇÃO
        if (responseData != null && responseData is Map) {
          final userDataRaw = responseData['user'];

          if (userDataRaw != null && userDataRaw is Map) {
            // Converte o Map<dynamic, dynamic> para o tipo correto Map<String, dynamic>
            final Map<String, dynamic> typedUserData =
                Map<String, dynamic>.from(userDataRaw);

            setState(() {
              _foundUser = typedUserData;
              _errorMessage =
                  null; // Garante que qualquer erro antigo seja limpo
            });
          } else {
            // A chave 'user' não foi encontrada ou não é um mapa
            setState(() {
              _errorMessage = "Usuário não encontrado.";
            });
          }
        } else {
          // A resposta inteira não é um mapa válido
          setState(() {
            _errorMessage = "Resposta inválida do servidor.";
          });
        }
        // ✅ FIM DA CORREÇÃO
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message ?? "Ocorreu um erro ao buscar.";
        });
      }
    } catch (e) {
      if (mounted) {
        print("FindFriendsPage: Erro inesperado ao processar a resposta: $e");
        setState(() {
          _errorMessage = "Erro ao processar a resposta. Tente novamente.";
        });
      }
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
      appBar: AppBar(title: const Text("Encontrar Amigos")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de busca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Buscar por ID Septima (ex: nome#1234)",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchUser,
                ),
              ),
              onSubmitted: (_) => _searchUser(),
            ),
            const SizedBox(height: 24),

            // Área de Resultados
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Text(_errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (_foundUser != null)
              _buildUserResultCard(_foundUser!)
            else
              const Text("Digite um ID para buscar um usuário."),
          ],
        ),
      ),
    );
  }

  Widget _buildUserResultCard(Map<String, dynamic> userData) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              (userData['photoURL'] != null && userData['photoURL']!.isNotEmpty)
                  ? NetworkImage(userData['photoURL']!)
                  : null,
          child: (userData['photoURL'] == null || userData['photoURL']!.isEmpty)
              ? Text(userData['nome']?[0] ?? '?')
              : null,
        ),
        title: Text(userData['nome'] ?? 'Usuário Desconhecido'),
        subtitle: Text(userData['descrição'] ?? 'Sem descrição.'),
        onTap: () {
          // Navega para a página de perfil público
          Navigator.push(
              context,
              FadeScalePageRoute(
                page: PublicProfilePage(
                  userId: userData['userId'],
                  initialUserData: userData,
                ),
              ));
        },
      ),
    );
  }
}
