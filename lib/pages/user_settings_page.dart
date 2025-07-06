// lib/pages/user_settings_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/redux/reducers.dart'; // Para AppThemeOption
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/services/subscription_manager.dart';
import 'package:redux/redux.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ViewModel para a página, obtendo todos os dados necessários do Redux
class _SettingsViewModel {
  final Map<String, dynamic> userDetails;
  final AppThemeOption activeThemeOption;
  final SubscriptionStatus subscriptionStatus;
  final String? activeProductId;
  final bool isGuest;

  _SettingsViewModel({
    required this.userDetails,
    required this.activeThemeOption,
    required this.subscriptionStatus,
    this.activeProductId,
    required this.isGuest,
  });
  static _SettingsViewModel fromStore(Store<AppState> store) {
    final subState = store.state.subscriptionState;
    final userDetails = store.state.userState.userDetails ?? {};
    bool isConsideredPremium = false;

    // Cenário 1: O estado Redux da assinatura já diz que é premium.
    if (subState.status == SubscriptionStatus.premiumActive) {
      isConsideredPremium = true;
    }
    // Cenário 2: Fallback - O estado Redux não foi atualizado, mas os detalhes do usuário no Firestore sim.
    // Isso é útil durante o carregamento inicial do app.
    else {
      final statusString = userDetails['subscriptionStatus'] as String?;
      final endDate =
          (userDetails['subscriptionEndDate'] as Timestamp?)?.toDate();

      if (statusString == 'active' &&
          endDate != null &&
          endDate.isAfter(DateTime.now())) {
        isConsideredPremium = true;
      }
    }

    return _SettingsViewModel(
      userDetails: userDetails,
      activeThemeOption:
          store.state.themeState.activeThemeOption, // <<< CORREÇÃO AQUI
      subscriptionStatus: isConsideredPremium
          ? SubscriptionStatus.premiumActive
          : subState.status,
      activeProductId: subState.activeProductId ?? userDetails['activePriceId'],
      isGuest: store.state.userState.isGuestUser,
    );
  }
}

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
    // Inicializa os controllers vazios. O StoreConnector cuidará de preenchê-los.
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();

    // O tema pode ser inicializado aqui, pois é menos provável que mude
    // enquanto a página está aberta, mas o StoreConnector também o gerencia.
    _selectedThemeOption = StoreProvider.of<AppState>(context, listen: false)
        .state
        .themeState
        .activeThemeOption;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleRestorePurchases() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verificando suas compras...')),
      );
    }
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      print("Erro ao tentar restaurar compras: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro: $e')),
        );
      }
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse(
        'https://benjamim-ep.github.io/septima_biblia_privacy_policy/privacy_policy.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Se não conseguir abrir a URL, mostra um erro para o usuário
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Não foi possível abrir a política de privacidade.')),
        );
      }
    }
  }
  // --- Funções de Lógica e Diálogos ---

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final storeInstance = StoreProvider.of<AppState>(context, listen: false);
      final newName = _nameController.text.trim();
      final newDescription = _descriptionController.text.trim();

      storeInstance.dispatch(UpdateUserFieldAction('nome', newName));
      storeInstance
          .dispatch(UpdateUserFieldAction('descrição', newDescription));

      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alterações salvas com sucesso!')),
          );
        }
      });
    }
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Saída'),
          content: const Text('Você tem certeza que deseja sair?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child:
                  const Text('Sair', style: TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await FirebaseAuth.instance.signOut();
                store.dispatch(UserLoggedOutAction());
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

  Future<void> _showDeleteAccountConfirmationDialog() async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text('Excluir Conta Permanentemente?',
              style: TextStyle(color: theme.colorScheme.error)),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Esta ação é irreversível.',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text(
                    'Todos os seus dados, incluindo progresso, notas e destaques, serão permanentemente apagados.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              child: const Text('Excluir Minha Conta'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                store.dispatch(DeleteUserAccountAction());
              },
            ),
          ],
        );
      },
    );
  }

  String _getThemeName(AppThemeOption option) {
    switch (option) {
      case AppThemeOption.green:
        return 'Verde (Padrão)';
      case AppThemeOption.septimaDark:
        return 'Septima Escuro';
      case AppThemeOption.septimaLight:
        return 'Septima Claro';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: StoreConnector<AppState, _SettingsViewModel>(
        converter: (store) => _SettingsViewModel.fromStore(store),
        onWillChange: (prev, next) {
          // Atualiza os controllers se os dados no Redux mudarem
          if (_nameController.text != (next.userDetails['nome'] ?? '')) {
            _nameController.text = next.userDetails['nome'] ?? '';
          }
          if (_descriptionController.text !=
              (next.userDetails['descrição'] ?? '')) {
            _descriptionController.text = next.userDetails['descrição'] ?? '';
          }
          // Atualiza a seleção de tema local
          if (_selectedThemeOption != next.activeThemeOption) {
            _selectedThemeOption = next.activeThemeOption;
          }
        },
        builder: (context, viewModel) {
          // O viewModel aqui é a instância de _SettingsViewModel
          final theme = Theme.of(context);
          // >>>>> CORREÇÃO AQUI <<<<<
          // A variável `isPremium` é determinada pela lógica consolidada no ViewModel
          final bool isPremium =
              viewModel.subscriptionStatus == SubscriptionStatus.premiumActive;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // --- SEÇÃO PERFIL ---
                  Text(
                    'Editar Perfil',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Por favor, insira seu nome.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration:
                        const InputDecoration(labelText: 'Descrição (Bio)'),
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
                                color: theme.colorScheme.onPrimary,
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt_outlined),
                    label:
                        Text(_isLoading ? 'Salvando...' : 'Salvar Alterações'),
                    onPressed: _isLoading ? null : _saveChanges,
                  ),
                  _buildDivider(),

                  // --- SEÇÃO TEMA ---
                  Text(
                    'Tema do Aplicativo',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  _buildThemeDropdown(theme),
                  _buildDivider(),

                  // --- SEÇÃO ASSINATURA ---
                  Text(
                    'Minha Assinatura',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  _buildSubscriptionSection(
                      // Passa as variáveis corretas
                      context,
                      theme,
                      isPremium,
                      viewModel),
                  _buildDivider(),

                  // --- SEÇÃO OUTRAS AÇÕES ---
                  Text(
                    'Outras Ações',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 16),
                  // <<< 3. ADICIONE O BOTÃO/LINK AQUI >>>
                  // Opção A: Usando um ListTile para um visual mais limpo
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Política de Privacidade'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: _launchPrivacyPolicy,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  ),

                  const SizedBox(height: 10), // Espaçamento
                  ElevatedButton.icon(
                    icon: Icon(Icons.logout, color: theme.colorScheme.onError),
                    label: const Text('Sair da Conta'),
                    onPressed: () => _showLogoutConfirmationDialog(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(Icons.no_accounts_outlined,
                        color: theme.colorScheme.error),
                    label: const Text('Excluir Minha Conta'),
                    onPressed: _showDeleteAccountConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.error.withOpacity(0.15),
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Widgets Auxiliares ---

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Divider(),
    );
  }

  Widget _buildThemeDropdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor ??
            theme.colorScheme.surface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppThemeOption>(
          value: _selectedThemeOption,
          isExpanded: true,
          dropdownColor: theme.dialogBackgroundColor,
          icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface),
          onChanged: (AppThemeOption? newValue) {
            if (newValue != null) {
              setState(() => _selectedThemeOption = newValue);
              StoreProvider.of<AppState>(context, listen: false)
                  .dispatch(SetThemeAction(newValue));
            }
          },
          items: AppThemeOption.values.map((option) {
            return DropdownMenuItem<AppThemeOption>(
              value: option,
              child: Text(_getThemeName(option),
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            );
          }).toList(),
        ),
      ),
    );
  }

  // <<< MÉTODO _buildSubscriptionButton RENOMEADO E MODIFICADO >>>
  Widget _buildSubscriptionSection(BuildContext context, ThemeData theme,
      bool isPremium, _SettingsViewModel viewModel) {
    if (isPremium) {
      // Se for premium, mostra apenas o botão de gerenciar
      return ElevatedButton.icon(
        icon: const Icon(Icons.manage_accounts_outlined),
        label: const Text('Gerenciar Assinatura'),
        onPressed: () async {
          if (viewModel.activeProductId != null) {
            try {
              const String packageName = "com.septima.septimabiblia";
              await SubscriptionManager.openSubscriptionManagement(
                  viewModel.activeProductId!, packageName);
            } catch (e) {
              if (context.mounted)
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
            }
          } else {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'ID do produto não encontrado para gerenciar a assinatura.')),
              );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
        ),
      );
    } else {
      // Se não for premium, mostra os botões de assinar e restaurar
      return Column(
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Seja Premium'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SubscriptionSelectionPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar Compras'),
            onPressed: _handleRestorePurchases,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.secondary,
            ),
          ),
        ],
      );
    }
  }
}
