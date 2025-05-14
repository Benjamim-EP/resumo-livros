// lib/pages/user_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart'; // Para AppThemeOption

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

  // Para o seletor de tema
  AppThemeOption? _selectedThemeOption; // Estado local para o dropdown

  @override
  void initState() {
    super.initState();
    final userDetails = StoreProvider.of<AppState>(context, listen: false)
            .state
            .userState
            .userDetails ??
        {};
    _nameController = TextEditingController(text: userDetails['nome'] ?? '');
    _descriptionController =
        TextEditingController(text: userDetails['descrição'] ?? '');

    // Inicializa o _selectedThemeOption com o tema ativo do Redux
    // Isso deve ser feito após o primeiro frame para garantir que o context do StoreProvider esteja disponível
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Verifica se o widget ainda está montado
        setState(() {
          _selectedThemeOption =
              StoreProvider.of<AppState>(context, listen: false)
                  .state
                  .themeState
                  .activeThemeOption;
        });
      }
    });
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
          backgroundColor:
              Theme.of(context).dialogBackgroundColor, // Usa cor do tema
          title: Text('Confirmar Saída',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Você tem certeza que deseja sair?',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7))),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7))),
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

      if (newName !=
          (storeInstance.state.userState.userDetails?['nome'] ?? '')) {
        storeInstance.dispatch(UpdateUserFieldAction('nome', newName));
      }
      if (newDescription !=
          (storeInstance.state.userState.userDetails?['descrição'] ?? '')) {
        storeInstance
            .dispatch(UpdateUserFieldAction('descrição', newDescription));
      }

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          // Verifica se o widget ainda está montado
          storeInstance.dispatch(LoadUserStatsAction());
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alterações salvas com sucesso!')),
          );
        }
      });
    }
  }

  String _getThemeName(AppThemeOption option) {
    switch (option) {
      case AppThemeOption.green:
        return 'Verde (Padrão)';
      case AppThemeOption.septimaDark:
        return 'Septima Escuro';
      case AppThemeOption.septimaLight:
        return 'Septima Claro';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Garante que _selectedThemeOption é inicializado se ainda for null
    // Isso pode acontecer se o addPostFrameCallback ainda não rodou.
    _selectedThemeOption ??= StoreProvider.of<AppState>(context, listen: false)
        .state
        .themeState
        .activeThemeOption;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        // backgroundColor e elevation são herdados do tema global
      ),
      body: StoreConnector<AppState, Map<String, dynamic>>(
          converter: (s) => s.state.userState.userDetails ?? {},
          onWillChange: (prevVm, newVm) {
            if (!mounted) return; // Proteção adicional
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
                    // --- Seção Editar Perfil ---
                    Text(
                      'Editar Perfil',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        // Estilos de label, filled, border, prefixIcon herdam do inputDecorationTheme
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
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Descrição (Bio)',
                        // Estilos herdam do inputDecorationTheme
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: _isLoading
                          ? Container(
                              width: 20,
                              height: 20,
                              padding: const EdgeInsets.all(2.0),
                              child: CircularProgressIndicator(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimary, // Cor de acordo com o botão
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.save_alt_outlined,
                              color: Theme.of(context).colorScheme.onPrimary),
                      label: Text(
                        _isLoading ? 'Salvando...' : 'Salvar Alterações',
                        style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      onPressed: _isLoading ? null : _saveChanges,
                      // Estilo do botão é herdado do elevatedButtonTheme
                    ),
                    const SizedBox(height: 32),
                    Divider(color: Theme.of(context).dividerColor),
                    const SizedBox(height: 16),

                    // --- Seção Tema do Aplicativo ---
                    Text(
                      'Tema do Aplicativo',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 4.0),
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                                  .inputDecorationTheme
                                  .fillColor ??
                              Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.5))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AppThemeOption>(
                          value: _selectedThemeOption,
                          isExpanded: true,
                          dropdownColor: Theme.of(context)
                              .dialogBackgroundColor, // Cor de fundo do dropdown
                          icon: Icon(Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.onSurface),
                          onChanged: (AppThemeOption? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedThemeOption =
                                    newValue; // Atualiza o estado local para o UI
                              });
                              StoreProvider.of<AppState>(context, listen: false)
                                  .dispatch(SetThemeAction(newValue));
                            }
                          },
                          items: AppThemeOption.values
                              .map<DropdownMenuItem<AppThemeOption>>(
                                  (AppThemeOption value) {
                            return DropdownMenuItem<AppThemeOption>(
                              value: value,
                              child: Text(
                                _getThemeName(value),
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Divider(color: Theme.of(context).dividerColor),
                    const SizedBox(height: 16),

                    // --- Seção Outras Ações ---
                    Text(
                      'Outras Ações',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.logout,
                          color: Theme.of(context).colorScheme.onError),
                      label: Text(
                        'Sair da Conta',
                        style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onError),
                      ),
                      onPressed: () => _showLogoutConfirmationDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .error, // Cor de erro do tema
                        // foregroundColor é definido pelo onPrimary do error
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
