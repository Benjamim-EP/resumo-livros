// lib/pages/user_settings_page.dart
import 'package:firebase_auth/firebase_auth.dart';
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
  AppThemeOption? _selectedThemeOption;

  @override
  void initState() {
    super.initState();
    // Acessa o store de forma segura no initState
    // É melhor usar addPostFrameCallback para interagir com o Store se houver risco do context não estar pronto
    // Mas para ler dados iniciais, listen: false é seguro.
    final userDetails = StoreProvider.of<AppState>(context, listen: false)
            .state
            .userState
            .userDetails ??
        {};
    _nameController = TextEditingController(text: userDetails['nome'] ?? '');
    _descriptionController =
        TextEditingController(text: userDetails['descrição'] ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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
    // Captura o context do StoreProvider ANTES do showDialog, se for usá-lo para despachar
    // No entanto, para o dispatch, o context da UserSettingsPage (widget.context ou simplesmente context) é suficiente
    // E para o Navigator.pop do diálogo, usamos dialogContext
    final store = StoreProvider.of<AppState>(context,
        listen: false); // Store da UserSettingsPage

    return showDialog<void>(
      context: context, // Contexto para exibir o diálogo
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Contexto específico do diálogo
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).dialogBackgroundColor,
          title: Text('Confirmar Saída',
              style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Você tem certeza que deseja sair?',
                    style: TextStyle(
                        color: Theme.of(dialogContext)
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
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7))),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child:
                  const Text('Sair', style: TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await FirebaseAuth.instance.signOut();
                print("Usuário deslogado do Firebase.");

                // Usa o 'store' capturado antes do showDialog ou o context da UserSettingsPage
                // que ainda deve estar montado neste ponto.
                store.dispatch(UserLoggedOutAction());

                // É crucial que o context usado para a navegação global seja o correto.
                // Usar o context da UserSettingsPage com rootNavigator: true.
                if (mounted) {
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil(
                          '/login', (Route<dynamic> route) => false);
                }
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

      // Verifica se houve realmente mudança antes de despachar
      bool changed = false;
      if (newName !=
          (storeInstance.state.userState.userDetails?['nome'] ?? '')) {
        storeInstance.dispatch(UpdateUserFieldAction('nome', newName));
        changed = true;
      }
      if (newDescription !=
          (storeInstance.state.userState.userDetails?['descrição'] ?? '')) {
        storeInstance
            .dispatch(UpdateUserFieldAction('descrição', newDescription));
        changed = true;
      }

      // Simula um delay para a operação de salvar e atualiza o estado
      // Em um app real, isso seria uma chamada assíncrona ao backend/Firestore
      Future.delayed(const Duration(milliseconds: 500), () {
        // Reduzido delay para feedback mais rápido
        if (mounted) {
          // A ação UpdateUserFieldAction já deve ter atualizado o Firestore via middleware.
          // A UserStatsLoadedAction (ou UserDetailsLoadedAction) no middleware de UpdateUserFieldAction
          // deve ter atualizado o estado do Redux.
          // Portanto, não é estritamente necessário despachar LoadUserStatsAction aqui DE NOVO,
          // a menos que UpdateUserFieldAction não recarregue os dados.
          // Vamos assumir que o middleware de UpdateUserFieldAction recarrega os dados após a escrita.
          // storeInstance.dispatch(LoadUserStatsAction()); // Opcional, dependendo do middleware

          setState(() => _isLoading = false);
          if (changed) {
            // Só mostra o SnackBar se algo mudou
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Alterações salvas com sucesso!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nenhuma alteração para salvar.')),
            );
          }
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
    } // Default não é necessário pois o enum cobre todos os casos.
  }

  @override
  Widget build(BuildContext context) {
    _selectedThemeOption ??= StoreProvider.of<AppState>(context, listen: false)
        .state
        .themeState
        .activeThemeOption;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: StoreConnector<AppState, Map<String, dynamic>>(
          // Usar um ViewModel mais específico pode ser melhor se UserDetails for grande
          converter: (s) => s.state.userState.userDetails ?? {},
          // onWillChange é chamado antes do builder se o ViewModel mudou.
          // Útil para atualizar controllers, mas cuidado com setState aqui.
          onWillChange: (Map<String, dynamic>? previousViewModel,
              Map<String, dynamic> newViewModel) {
            // Atualiza os controllers APENAS se o valor no Redux realmente mudou
            // e se o valor do controller é diferente, para evitar loops de atualização.
            // Isso é mais seguro do que no initState apenas, caso os dados sejam atualizados
            // no Redux enquanto a página está visível.
            if (mounted) {
              // Garante que o widget está na árvore
              if (_nameController.text != (newViewModel['nome'] ?? '')) {
                _nameController.text = newViewModel['nome'] ?? '';
              }
              if (_descriptionController.text !=
                  (newViewModel['descrição'] ?? '')) {
                _descriptionController.text = newViewModel['descrição'] ?? '';
              }
            }
          },
          builder: (context, userDetails) {
            // userDetails aqui é o resultado do converter
            // Não é ideal atualizar controllers dentro do builder, pois pode causar loops.
            // _nameController.text = userDetails['nome'] ?? ''; // MOVIDO PARA onWillChange
            // _descriptionController.text = userDetails['descrição'] ?? ''; // MOVIDO PARA onWillChange

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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        // Estilos de label, filled, border, prefixIcon herdam do inputDecorationTheme
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira seu nome.';
                        }
                        if (value.length > 50) {
                          // Exemplo de validação de tamanho
                          return 'O nome não pode exceder 50 caracteres.';
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
                      validator: (value) {
                        if (value != null && value.length > 200) {
                          // Exemplo
                          return 'A descrição não pode exceder 200 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: _isLoading
                          ? Container(
                              width: 20,
                              height: 20,
                              padding: const EdgeInsets.all(2.0),
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.onPrimary,
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
                    ),
                    const SizedBox(height: 32),
                    Divider(color: Theme.of(context).dividerColor),
                    const SizedBox(height: 16),

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
                          value: _selectedThemeOption, // Usa o estado local
                          isExpanded: true,
                          dropdownColor:
                              Theme.of(context).dialogBackgroundColor,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.onSurface),
                          onChanged: (AppThemeOption? newValue) {
                            if (newValue != null) {
                              setState(() {
                                // Atualiza o estado local para o UI do dropdown
                                _selectedThemeOption = newValue;
                              });
                              // Despacha a ação para o Redux (que também persistirá)
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
                        backgroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Espaço extra no final
                  ],
                ),
              ),
            );
          }),
    );
  }
}
