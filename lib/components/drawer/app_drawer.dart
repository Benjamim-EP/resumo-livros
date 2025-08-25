// lib/components/drawer/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:provider/provider.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/services/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:septima_biblia/services/notification_service.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

// ViewModel para buscar os dados do usuário para o cabeçalho do Drawer
class _DrawerViewModel {
  final String? photoUrl;
  final String name;
  final String? septimaId;
  final String? denomination;
  final int unreadCount;

  _DrawerViewModel({
    this.photoUrl,
    required this.name,
    this.septimaId,
    this.denomination,
    required this.unreadCount,
  });

  static _DrawerViewModel fromStore(Store<AppState> store) {
    final details = store.state.userState.userDetails ?? {};
    String? generatedId;
    final username = details['username'] as String?;
    final discriminator = details['discriminator'] as String?;
    if (username != null && discriminator != null) {
      generatedId = '$username#$discriminator';
    }

    return _DrawerViewModel(
      photoUrl: details['photoURL'] as String?,
      name: details['nome'] as String? ?? 'Usuário',
      septimaId: generatedId,
      denomination: details['denomination'] as String?,
      unreadCount: store.state.userState.unreadNotificationsCount,
    );
  }
}

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with WidgetsBindingObserver {
  bool _notificationsEnabled = true;
  bool _isLoadingPreference = true;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Adiciona este widget como um observador do ciclo de vida do app
    WidgetsBinding.instance.addObserver(this);
    // Faz a verificação inicial ao construir o widget
    _syncNotificationStatus();
  }

  @override
  void dispose() {
    // Remove o observador para evitar memory leaks
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Observa as mudanças no ciclo de vida do aplicativo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Se o app voltou para o primeiro plano (ex: voltando das configurações do Android)
    if (state == AppLifecycleState.resumed) {
      print(
          "Drawer: App voltou para o primeiro plano. Sincronizando status da notificação.");
      // Sincroniza o estado do switch com a permissão real do sistema
      _syncNotificationStatus();
    }
  }

  /// Sincroniza o estado do switch com a permissão real do sistema E o SharedPreferences.
  Future<void> _syncNotificationStatus() async {
    // 1. Pega a permissão REAL do sistema operacional
    final status = await Permission.notification.status;
    final bool permissionGranted = status.isGranted;

    // 2. Pega a preferência SALVA pelo usuário no app
    final prefs = await SharedPreferences.getInstance();
    final bool userPreference =
        prefs.getBool(NotificationService.notificationsEnabledKey) ?? true;

    // 3. O estado final do switch é a combinação dos dois:
    //    Só deve estar "ligado" se o usuário QUER (preferência) E PODE (permissão).
    final bool finalStatus = userPreference && permissionGranted;

    if (mounted) {
      setState(() {
        _notificationsEnabled = finalStatus;
        _isLoadingPreference = false;
      });
    }

    // 4. Se houver uma discrepância, corrige o SharedPreferences para refletir a realidade.
    if (userPreference != finalStatus) {
      await prefs.setBool(
          NotificationService.notificationsEnabledKey, finalStatus);
    }
  }

  /// Lida com a interação do usuário com o switch.
  Future<void> _updateNotificationPreference(bool newValue) async {
    final prefs = await SharedPreferences.getInstance();

    if (newValue == true) {
      // O usuário está TENTANDO ATIVAR as notificações.
      var status = await Permission.notification.status;

      if (status.isGranted) {
        print("Drawer: Permissão já concedida. Ativando lembretes.");
        setState(() => _notificationsEnabled = true);
        await prefs.setBool(NotificationService.notificationsEnabledKey, true);
        await _notificationService.scheduleDailyDevotionals();
        if (mounted)
          CustomNotificationService.showSuccess(
              context, "Lembretes diários ativados!");
        return;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        print(
            "Drawer: Permissão negada permanentemente. Abrindo diálogo de configurações.");
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text("Permissão Necessária"),
              content: const Text(
                  "Para ativar os lembretes, você precisa permitir as notificações manualmente nas configurações do seu dispositivo para este aplicativo."),
              actions: [
                TextButton(
                  child: const Text("Cancelar"),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text("Abrir Configurações"),
                  onPressed: () {
                    openAppSettings();
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          );
        }
        setState(() => _notificationsEnabled = false);
        return;
      }

      if (status.isDenied) {
        print(
            "Drawer: Permissão foi negada anteriormente. Solicitando novamente...");
        final newStatus = await Permission.notification.request();

        if (newStatus.isGranted) {
          print("Drawer: Permissão agora concedida. Agendando lembretes.");
          setState(() => _notificationsEnabled = true);
          await prefs.setBool(
              NotificationService.notificationsEnabledKey, true);
          await _notificationService.scheduleDailyDevotionals();
          if (mounted)
            CustomNotificationService.showSuccess(
                context, "Lembretes diários ativados!");
        } else {
          print("Drawer: Usuário negou a permissão novamente.");
          if (mounted)
            CustomNotificationService.showError(
                context, "Permissão de notificação negada.");
          setState(() => _notificationsEnabled = false);
        }
      }
    } else {
      // O usuário está DESATIVANDO as notificações.
      print(
          "Drawer: Desativando lembretes e cancelando notificações agendadas.");
      setState(() {
        _notificationsEnabled = false;
      });
      await prefs.setBool(NotificationService.notificationsEnabledKey, false);
      await _notificationService.cancelAllNotifications();
      if (mounted) {
        CustomNotificationService.showSuccess(
            context, "Lembretes diários desativados.");
      }
    }
  }

  /// Abre o cliente de e-mail padrão do usuário com informações pré-preenchidas.
  Future<void> _launchEmailSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'sep7imadev@gmail.com', // <<< SUBSTITUA PELO SEU E-MAIL
      queryParameters: {
        'subject': 'Suporte App Septima Bíblia',
        'body':
            'Olá,\n\nEstou entrando em contato sobre o aplicativo Septima Bíblia.\n\n(Descreva sua dúvida ou problema aqui)\n\n---'
      },
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        // Fallback para caso o dispositivo não tenha um cliente de e-mail configurado
        _showLaunchError('Não foi possível abrir o cliente de e-mail.');
      }
    } catch (e) {
      _showLaunchError('Ocorreu um erro ao tentar abrir o e-mail: $e');
    }
  }

  /// Abre uma conversa no WhatsApp com o número de suporte.
  Future<void> _launchWhatsAppSupport() async {
    // IMPORTANTE: Use o número completo com o código do país, sem o '+' e sem espaços/hífens.
    const String phoneNumber = '5598989064247'; // <<< SUBSTITUA PELO SEU NÚMERO
    const String message =
        'Olá! Preciso de ajuda com o aplicativo Septima Bíblia.';

    // Codifica a mensagem para ser usada na URL
    final String encodedMessage = Uri.encodeComponent(message);

    // A URL universal do WhatsApp que funciona em Android e iOS
    final Uri whatsappUrl =
        Uri.parse("https://wa.me/$phoneNumber?text=$encodedMessage");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        // `externalApplication` garante que abrirá o app do WhatsApp, e não um navegador interno.
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        _showLaunchError(
            'Não foi possível abrir o WhatsApp. Verifique se ele está instalado.');
      }
    } catch (e) {
      _showLaunchError('Ocorreu um erro ao tentar abrir o WhatsApp: $e');
    }
  }

  /// Mostra uma SnackBar de erro se não for possível abrir o link.
  void _showLaunchError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final l10n = AppLocalizations.of(context)!; // Instância de localização

    return StoreConnector<AppState, _DrawerViewModel>(
      converter: (store) => _DrawerViewModel.fromStore(store),
      builder: (context, viewModel) {
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _buildDrawerHeader(context, viewModel),
              StoreConnector<AppState, bool>(
                converter: (store) => store.state.userState.hasBeenReferred,
                builder: (context, hasBeenReferred) {
                  if (hasBeenReferred) {
                    return const SizedBox.shrink();
                  }
                  return const Column(
                    children: [
                      _ReferralInputSection(),
                      Divider(),
                    ],
                  );
                },
              ),
              _buildDrawerItem(
                leadingWidget: const Icon(Icons.people_alt_outlined),
                text: l10n.drawerFriends, // <-- Usando l10n
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/friends');
                },
              ),
              _buildDrawerItem(
                leadingWidget: const Icon(Icons.notifications_outlined),
                text: l10n.drawerNotifications, // <-- Usando l10n
                badgeCount: viewModel.unreadCount,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
              _buildDrawerItem(
                leadingWidget: const Icon(Icons.edit_note_outlined),
                text: l10n.drawerDevotionalDiary, // <-- Usando l10n
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/diary');
                },
              ),
              _isLoadingPreference
                  ? ListTile(title: Text("Carregando configuração..."))
                  : SwitchListTile(
                      title: Text(l10n.drawerDailyReminders), // <-- Usando l10n
                      value: _notificationsEnabled,
                      onChanged: _updateNotificationPreference,
                      secondary: Icon(
                        _notificationsEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                      ),
                    ),
              const Divider(),
              _buildDrawerItem(
                leadingWidget: const Icon(Icons.settings_outlined),
                text: l10n.drawerSettingsAndProfile, // <-- Usando l10n
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/userSettings');
                },
              ),
              _buildDrawerItem(
                leadingWidget: const Icon(Icons.logout),
                text: l10n.drawerLogout, // <-- Usando l10n
                onTap: () => _showLogoutConfirmationDialog(context),
              ),
              _buildLanguageSelector(context, languageProvider, l10n),
              const Divider(height: 1),
              ListTile(
                title: Text(
                  l10n.drawerSupport, // <-- Usando l10n
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildDrawerItem(
                leadingWidget: const Icon(Icons.email_outlined),
                text: l10n.drawerContactEmail, // <-- Usando l10n
                onTap: _launchEmailSupport,
              ),
              _buildDrawerItem(
                leadingWidget: Image.asset(
                  'assets/icon/whatsapp.png',
                  width: 24,
                  height: 24,
                ),
                text: l10n.drawerContactWhatsapp, // <-- Usando l10n
                onTap: _launchWhatsAppSupport,
              ),
              const Divider(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageSelector(
      BuildContext context, LanguageProvider provider, AppLocalizations l10n) {
    // Define os idiomas que você suporta
    final supportedLanguages = {
      'pt': 'Português',
      'en': 'English',
    };

    // Determina o código do idioma atual (ex: 'pt', 'en')
    // Se appLocale for nulo, ele usa o idioma do dispositivo.
    final currentLangCode = provider.appLocale?.languageCode ??
        Localizations.localeOf(context).languageCode;

    return ListTile(
      leading: const Icon(Icons.language_outlined),
      title: Text(l10n.drawerLanguage),
      trailing: DropdownButton<String>(
        value: supportedLanguages.containsKey(currentLangCode)
            ? currentLangCode
            : 'pt', // Valor padrão 'pt'
        underline: const SizedBox(), // Remove a linha de baixo
        items: supportedLanguages.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: (String? newLanguageCode) {
          if (newLanguageCode != null) {
            // Chama o método no provider para mudar o idioma
            provider.changeLocale(newLanguageCode);
          }
        },
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, _DrawerViewModel viewModel) {
    final theme = Theme.of(context);
    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: viewModel.photoUrl != null
                ? NetworkImage(viewModel.photoUrl!)
                : null,
            child: viewModel.photoUrl == null
                ? Text(viewModel.name.isNotEmpty ? viewModel.name[0] : 'U',
                    style: const TextStyle(fontSize: 28))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  viewModel.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (viewModel.septimaId != null)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: viewModel.septimaId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("ID copiado!")),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          viewModel.septimaId!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7)),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy_all_outlined,
                            size: 14,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7)),
                      ],
                    ),
                  ),
                if (viewModel.denomination != null &&
                    viewModel.denomination!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      viewModel.denomination!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required Widget leadingWidget, // <<< Agora espera um Widget completo
    required String text,
    required GestureTapCallback onTap,
    int badgeCount = 0,
  }) {
    return ListTile(
      leading: badgeCount > 0
          ? Badge(
              label: Text('$badgeCount'),
              child: leadingWidget, // <<< Usa o Widget diretamente
            )
          : leadingWidget, // <<< Usa o Widget diretamente
      title: Text(text),
      onTap: onTap,
    );
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    final l10n =
        AppLocalizations.of(context)!; // Pega a instância de localização
    final store = StoreProvider.of<AppState>(context, listen: false);

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.logoutConfirmTitle), // <-- Usando l10n
          content: Text(l10n.logoutConfirmContent), // <-- Usando l10n
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel), // <-- Usando l10n
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(l10n.drawerLogout, // <-- Usando l10n
                  style: const TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await FirebaseAuth.instance.signOut();
                store.dispatch(UserLoggedOutAction());
              },
            ),
          ],
        );
      },
    );
  }
}

class _ReferralInputSection extends StatefulWidget {
  const _ReferralInputSection();

  @override
  State<_ReferralInputSection> createState() => _ReferralInputSectionState();
}

class _ReferralInputSectionState extends State<_ReferralInputSection> {
  final _referralController = TextEditingController();
  bool _isLoading = false;

  void _submitCode() {
    final l10n = AppLocalizations.of(context)!; // Pega a instância aqui
    final code = _referralController.text.trim();
    if (code.isEmpty || !code.contains('#')) {
      CustomNotificationService.showError(
          context, l10n.referralInvalidIdError); // <-- Usando l10n
      return;
    }

    setState(() => _isLoading = true);

    // A ação do Redux cuidará da chamada da Cloud Function
    // e o Future.whenComplete vai garantir que o loading pare.
    StoreProvider.of<AppState>(context, listen: false)
        .dispatch(SubmitReferralCodeAction(code))
        .whenComplete(() {
      if (mounted) {
        setState(() => _isLoading = false);
        _referralController.clear();
      }
    });
  }

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.referralQuestion, // <-- Usando l10n
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.referralDescription, // <-- Usando l10n
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _referralController,
                  decoration: InputDecoration(
                    hintText: l10n.referralIdHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitCode(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isLoading ? null : _submitCode,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                tooltip: l10n.referralValidateCode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
