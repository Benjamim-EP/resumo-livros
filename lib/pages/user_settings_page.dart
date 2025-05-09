// lib/pages/user_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  _UserSettingsPageState createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Inicializa os controllers com os dados atuais do usuário do Redux
    final userDetails = store.state.userState.userDetails ?? {};
    _nameController = TextEditingController(text: userDetails['nome'] ?? '');
    _descriptionController =
        TextEditingController(text: userDetails['descrição'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          title: const Text('Confirmar Saída',
              style: TextStyle(color: Colors.white)),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Você tem certeza que deseja sair?',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child:
                  const Text('Sair', style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                StoreProvider.of<AppState>(context, listen: false)
                    .dispatch(UserLoggedOutAction());
                Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login', (Route<dynamic> route) => false);
              },
            ),
          ],
        );
      },
    );
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final storeInstance = StoreProvider.of<AppState>(context, listen: false);
      final newName = _nameController.text.trim();
      final newDescription = _descriptionController.text.trim();

      // Despacha ações para atualizar os campos no Firestore e Redux
      // O middleware UpdateUserFieldAction cuidará da atualização no Firestore
      // e depois o UserStatsLoadedAction (ou UserDetailsLoadedAction) atualizará o Redux
      if (newName !=
          (storeInstance.state.userState.userDetails?['nome'] ?? '')) {
        storeInstance.dispatch(UpdateUserFieldAction('nome', newName));
      }
      if (newDescription !=
          (storeInstance.state.userState.userDetails?['descrição'] ?? '')) {
        storeInstance
            .dispatch(UpdateUserFieldAction('descrição', newDescription));
      }

      // Simula um delay para o salvamento e recarrega os dados para refletir na UI
      Future.delayed(const Duration(seconds: 1), () {
        storeInstance.dispatch(
            LoadUserStatsAction()); // Recarrega os detalhes do usuário
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alterações salvas com sucesso!')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações da Conta'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StoreConnector<AppState, Map<String, dynamic>>(
          converter: (s) => s.state.userState.userDetails ?? {},
          onWillChange: (prevVm, newVm) {
            // Atualiza os controllers se os dados do Redux mudarem externamente
            if (prevVm?['nome'] != newVm['nome']) {
              _nameController.text = newVm['nome'] ?? '';
            }
            if (prevVm?['descrição'] != newVm['descrição']) {
              _descriptionController.text = newVm['descrição'] ?? '';
            }
          },
          builder: (context, userDetails) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Editar Perfil',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.person_outline,
                            color: Colors.white70),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira seu nome.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Descrição (Bio)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.description_outlined,
                            color: Colors.white70),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        // Descrição pode ser opcional
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: _isLoading
                          ? Container(
                              width: 20,
                              height: 20,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_alt_outlined,
                              color: Colors.black),
                      label: Text(
                        _isLoading ? 'Salvando...' : 'Salvar Alterações',
                        style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 20),
                    Text(
                      'Outras Ações',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Sair da Conta',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      onPressed: () => _showLogoutConfirmationDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
    );
  }
}
