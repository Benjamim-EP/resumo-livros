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

// ViewModel (sem alterações)
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
    WidgetsBinding.instance.addObserver(this);
    _syncNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncNotificationStatus();
    }
  }

  Future<void> _syncNotificationStatus() async {
    final status = await Permission.notification.status;
    final bool permissionGranted = status.isGranted;
    final prefs = await SharedPreferences.getInstance();
    final bool userPreference =
        prefs.getBool(NotificationService.notificationsEnabledKey) ?? true;
    final bool finalStatus = userPreference && permissionGranted;

    if (mounted) {
      setState(() {
        _notificationsEnabled = finalStatus;
        _isLoadingPreference = false;
      });
    }
    if (userPreference != finalStatus) {
      await prefs.setBool(
          NotificationService.notificationsEnabledKey, finalStatus);
    }
  }

  Future<void> _updateNotificationPreference(bool newValue) async {
    final prefs = await SharedPreferences.getInstance();
    final l10n = AppLocalizations.of(context)!;

    if (newValue == true) {
      var status = await Permission.notification.status;

      if (status.isGranted) {
        setState(() => _notificationsEnabled = true);
        await prefs.setBool(NotificationService.notificationsEnabledKey, true);
        await _notificationService.scheduleDailyDevotionals();
        if (mounted)
          CustomNotificationService.showSuccess(
              context, "Lembretes diários ativados!");
        return;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.permissionRequiredTitle),
              content: Text(l10n.permissionRequiredContent),
              actions: [
                TextButton(
                  child: Text(l10n.cancel),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: Text(l10n.openSettings),
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
        final newStatus = await Permission.notification.request();

        if (newStatus.isGranted) {
          setState(() => _notificationsEnabled = true);
          await prefs.setBool(
              NotificationService.notificationsEnabledKey, true);
          await _notificationService.scheduleDailyDevotionals();
          if (mounted)
            CustomNotificationService.showSuccess(
                context, "Lembretes diários ativados!");
        } else {
          if (mounted)
            CustomNotificationService.showError(
                context, "Permissão de notificação negada.");
          setState(() => _notificationsEnabled = false);
        }
      }
    } else {
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

  Future<void> _launchEmailSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'sep7imadev@gmail.com',
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
        _showLaunchError('Não foi possível abrir o cliente de e-mail.');
      }
    } catch (e) {
      _showLaunchError('Ocorreu um erro ao tentar abrir o e-mail: $e');
    }
  }

  Future<void> _launchWhatsAppSupport() async {
    const String phoneNumber = '5598981809156';
    const String message =
        'Olá! Preciso de ajuda com o aplicativo Septima Bíblia.';
    final String encodedMessage = Uri.encodeComponent(message);
    final Uri whatsappUrl =
        Uri.parse("https://wa.me/$phoneNumber?text=$encodedMessage");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        _showLaunchError(
            'Não foi possível abrir o WhatsApp. Verifique se ele está instalado.');
      }
    } catch (e) {
      _showLaunchError('Ocorreu um erro ao tentar abrir o WhatsApp: $e');
    }
  }

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
    final l10n = AppLocalizations.of(context)!;

    return StoreConnector<AppState, _DrawerViewModel>(
      converter: (store) => _DrawerViewModel.fromStore(store),
      builder: (context, viewModel) {
        return Drawer(
          // <<< INÍCIO DA CORREÇÃO >>>
          child: SafeArea(
            // Envolve a ListView com SafeArea para evitar a UI do sistema
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
                  text: l10n.drawerFriends,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/friends');
                  },
                ),
                _buildDrawerItem(
                  leadingWidget: const Icon(Icons.notifications_outlined),
                  text: l10n.drawerNotifications,
                  badgeCount: viewModel.unreadCount,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                _buildDrawerItem(
                  leadingWidget: const Icon(Icons.edit_note_outlined),
                  text: l10n.drawerDevotionalDiary,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/diary');
                  },
                ),
                _isLoadingPreference
                    ? const ListTile(title: Text("Carregando configuração..."))
                    : SwitchListTile(
                        title: Text(l10n.drawerDailyReminders),
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
                  text: l10n.drawerSettingsAndProfile,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/userSettings');
                  },
                ),
                _buildDrawerItem(
                  leadingWidget: const Icon(Icons.logout),
                  text: l10n.drawerLogout,
                  onTap: () => _showLogoutConfirmationDialog(context),
                ),
                _buildLanguageSelector(context, languageProvider, l10n),
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    l10n.drawerSupport,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildDrawerItem(
                  leadingWidget: const Icon(Icons.email_outlined),
                  text: l10n.drawerContactEmail,
                  onTap: _launchEmailSupport,
                ),
                _buildDrawerItem(
                  leadingWidget: Image.asset(
                    'assets/icon/whatsapp.png',
                    width: 24,
                    height: 24,
                  ),
                  text: l10n.drawerContactWhatsapp,
                  onTap: _launchWhatsAppSupport,
                ),
                const Divider(),
              ],
            ),
          ),
          // <<< FIM DA CORREÇÃO >>>
        );
      },
    );
  }

  Widget _buildLanguageSelector(
      BuildContext context, LanguageProvider provider, AppLocalizations l10n) {
    final supportedLanguages = {
      'pt': 'Português',
      'en': 'English',
    };
    final currentLangCode = provider.appLocale?.languageCode ??
        Localizations.localeOf(context).languageCode;
    return ListTile(
      leading: const Icon(Icons.language_outlined),
      title: Text(l10n.drawerLanguage),
      trailing: DropdownButton<String>(
        value: supportedLanguages.containsKey(currentLangCode)
            ? currentLangCode
            : 'pt',
        underline: const SizedBox(),
        items: supportedLanguages.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: (String? newLanguageCode) {
          if (newLanguageCode != null) {
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
    required Widget leadingWidget,
    required String text,
    required GestureTapCallback onTap,
    int badgeCount = 0,
  }) {
    return ListTile(
      leading: badgeCount > 0
          ? Badge(
              label: Text('$badgeCount'),
              child: leadingWidget,
            )
          : leadingWidget,
      title: Text(text),
      onTap: onTap,
    );
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final store = StoreProvider.of<AppState>(context, listen: false);

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.logoutConfirmTitle),
          content: Text(l10n.logoutConfirmContent),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(l10n.drawerLogout,
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
    final l10n = AppLocalizations.of(context)!;
    final code = _referralController.text.trim();
    if (code.isEmpty || !code.contains('#')) {
      CustomNotificationService.showError(context, l10n.referralInvalidIdError);
      return;
    }

    setState(() => _isLoading = true);

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
            l10n.referralQuestion,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.referralDescription,
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
