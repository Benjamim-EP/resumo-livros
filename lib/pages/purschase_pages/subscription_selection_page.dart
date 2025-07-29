// lib/pages/purschase_pages/subscription_selection_page.dart

import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/login_required.dart';
import 'package:septima_biblia/consts.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';

class _ViewModel {
  final bool isLoading;
  final AppThemeOption activeTheme;
  final bool isGuest;

  _ViewModel({
    required this.isLoading,
    required this.activeTheme,
    required this.isGuest,
  });

  static _ViewModel fromStore(Store<AppState> store) {
    return _ViewModel(
      isLoading: store.state.subscriptionState.isLoading,
      activeTheme: store.state.themeState.activeThemeOption,
      isGuest: store.state.userState.isGuestUser,
    );
  }
}

class SubscriptionSelectionPage extends StatefulWidget {
  const SubscriptionSelectionPage({super.key});

  @override
  State<SubscriptionSelectionPage> createState() =>
      _SubscriptionSelectionPageState();
}

class _SubscriptionSelectionPageState extends State<SubscriptionSelectionPage> {
  // ==========================================================
  // <<< NOVA FUNÇÃO PARA LIDAR COM O PAGAMENTO PIX >>>
  // ==========================================================
  Future<void> _handlePixPayment(BuildContext context) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    if (store.state.userState.isGuestUser) {
      showLoginRequiredDialog(context, featureName: "realizar um pagamento");
      return;
    }

    final functions =
        FirebaseFunctions.instanceFor(region: "southamerica-east1");
    final callable = functions.httpsCallable('createMercadoPagoPix');

    // Mostra um loader enquanto chama a Cloud Function
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final result = await callable.call<Map<String, dynamic>>();
      final data = result.data;
      final String? qrCodeBase64 = data['qr_code_base64'];
      final String? qrCodeCopiaECola = data['qr_code_copia_e_cola'];

      if (qrCodeBase64 == null || qrCodeCopiaECola == null) {
        throw Exception("Resposta do servidor inválida para o PIX.");
      }

      if (context.mounted) {
        Navigator.pop(context); // Fecha o loader

        // Mostra o diálogo com o QR Code para o usuário
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("Pague com PIX para Ativar"),
            content: SingleChildScrollView(
              // Para evitar overflow em telas pequenas
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.memory(base64Decode(qrCodeBase64)),
                  const SizedBox(height: 16),
                  const Text("Escaneie o QR Code ou use o código abaixo:",
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  TextField(
                    controller: TextEditingController(text: qrCodeCopiaECola),
                    readOnly: true,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: "Copiar código",
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: qrCodeCopiaECola));
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                                content: Text("Código PIX copiado!")),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Após o pagamento, seu acesso será liberado automaticamente em alguns instantes.",
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Fechar"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Fecha o loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Erro ao gerar PIX: ${e is FirebaseFunctionsException ? e.message : e}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const bool isPlayStore = bool.fromEnvironment('IS_PLAY_STORE');
    final List<Map<String, String>> availablePlans =
        getAvailableSubscriptions(isPlayStore);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seja Septima Premium"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textTheme.bodyLarge?.color,
      ),
      body: StoreConnector<AppState, _ViewModel>(
        converter: (store) => _ViewModel.fromStore(store),
        builder: (context, viewModel) {
          if (viewModel.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Processando..."),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                _buildFreePlanCard(context, theme),
                const SizedBox(height: 24),
                _buildPremiumPlanCard(context, theme, viewModel.activeTheme,
                    viewModel.isGuest, availablePlans, isPlayStore),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    // Mensagem dinâmica com base no flavor
                    isPlayStore
                        ? "As assinaturas são processadas pela Google Play Store e podem ser gerenciadas a qualquer momento nas configurações da sua conta na Play Store."
                        : "As assinaturas são processadas de forma segura pela Stripe e podem ser gerenciadas a qualquer momento através do portal do cliente.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFreePlanCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Plano Gratuito", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            _buildFeatureRow(Icons.menu_book_outlined,
                "Bíblia completa em múltiplas versões", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(
                Icons.comment_bank_outlined, "Comentários por seção", theme),
            const SizedBox(height: 16),
            _buildFeatureRow(
                Icons.wb_sunny_outlined, "Devocionais Diários", theme),
            const Divider(height: 32),
            _buildLimitationRow(
                Icons.ad_units_outlined, "Anúncios durante a navegação", theme),
            const SizedBox(height: 16),
            _buildLimitationRow(Icons.monetization_on_outlined,
                "Recursos de IA limitados por moedas", theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPlanCard(
      BuildContext context,
      ThemeData theme,
      AppThemeOption activeTheme,
      bool isGuest,
      List<Map<String, String>> plans,
      bool isPlayStoreBuild) {
    // <<< Adicionado isPlayStoreBuild
    return Card(
      elevation: 8,
      shadowColor: Colors.amber.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade200.withOpacity(0.2),
              theme.cardColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.center,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium_outlined,
                      color: Colors.amber.shade700, size: 32),
                  const SizedBox(width: 12),
                  Text("Septima Premium", style: theme.textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Desbloqueie todas as ferramentas e estude sem limites.",
                style: theme.textTheme.bodyLarge,
              ),
              const Divider(height: 32),
              _buildPremiumFeatureRow(
                  Icons.auto_awesome, "Ferramentas de IA Ilimitadas", theme,
                  isHighlighted: true),
              _buildSubFeatureRow("Busca Semântica na Bíblia e Sermões", theme),
              _buildSubFeatureRow("Resumos de Comentários com IA", theme),
              _buildSubFeatureRow("Chat com Spurgeon AI", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(
                  Icons.translate_rounded, "Aprofunde-se nos Originais", theme),
              _buildSubFeatureRow("Hebraico e Grego Interlinear", theme),
              _buildSubFeatureRow("Léxico de Strong Completo", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(
                  Icons.menu_book, "Experiência de Estudo Pura", theme),
              _buildSubFeatureRow("Navegação totalmente sem anúncios", theme),
              _buildSubFeatureRow("Geração de PDFs ilimitada", theme),
              _buildSubFeatureRow(
                  "Destaques coloridos em toda a biblioteca", theme),
              const SizedBox(height: 16),
              _buildPremiumFeatureRow(Icons.local_library_outlined,
                  "Biblioteca Premium em Expansão", theme),
              _buildSubFeatureRow("História da Igreja (8 volumes)", theme),
              _buildSubFeatureRow("Institutas de Turretin (3 volumes)", theme),
              _buildSubFeatureRow("Acesso antecipado a novos recursos", theme),
              const Divider(height: 40),

              // Constrói os botões de assinatura
              ...plans.map((plan) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildPlanOptionButton(
                    context,
                    theme,
                    title: plan['title']!,
                    price: plan['price']!,
                    productId: plan['id']!,
                    isGuest: isGuest,
                  ),
                );
              }).toList(),

              // <<< LÓGICA CONDICIONAL PARA O BOTÃO PIX >>>
              if (!isPlayStoreBuild) ...[
                const Divider(height: 8, indent: 40, endIndent: 40),
                const SizedBox(height: 8),
                Text(
                  "Ou pague uma única vez por 1 Mês de Acesso",
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.pix),
                    // <<< LABEL ATUALIZADO >>>
                    label: const Text("Pagar com PIX (R\$ 19,90)"),
                    onPressed: () => _handlePixPayment(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B6DE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12)),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // Widgets auxiliares (sem alterações)
  Widget _buildFeatureRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline,
            color: theme.colorScheme.secondary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text,
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.9))),
        ),
      ],
    );
  }

  Widget _buildLimitationRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            color: theme.colorScheme.onSurface.withOpacity(0.5), size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text,
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7))),
        ),
      ],
    );
  }

  Widget _buildPremiumFeatureRow(IconData icon, String text, ThemeData theme,
      {bool isHighlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber.shade700, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight:
                    isHighlighted ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ],
    );
  }

  Widget _buildSubFeatureRow(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 38.0, top: 4.0),
      child: Text("• $text",
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.75))),
    );
  }

  Widget _buildPlanOptionButton(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String price,
    required String productId,
    required bool isGuest,
  }) {
    return StoreConnector<AppState, _ViewModel>(
        converter: (store) => _ViewModel.fromStore(store),
        builder: (context, viewModel) {
          return Material(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: viewModel.isLoading
                  ? null
                  : () {
                      if (isGuest) {
                        showLoginRequiredDialog(context,
                            featureName: "fazer uma assinatura");
                      } else {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(
                          InitiateGooglePlaySubscriptionAction(
                              productId: productId),
                        );
                      }
                    },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold)),
                          Text(price,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.8))),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
