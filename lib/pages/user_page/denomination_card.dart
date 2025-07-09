// lib/pages/user_page/denomination_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para Clipboard
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';

// ViewModel para extrair apenas os dados necessários do estado
class _ViewModel {
  final String? denomination;
  final String? septimaId;

  _ViewModel({this.denomination, this.septimaId});

  static _ViewModel fromStore(Store<AppState> store) {
    final userDetails = store.state.userState.userDetails;
    String? id;
    if (userDetails != null) {
      final username = userDetails['username'] as String?;
      final discriminator = userDetails['discriminator'] as String?;
      if (username != null && discriminator != null) {
        id = '$username#$discriminator';
      }
    }
    return _ViewModel(
      denomination: userDetails?['denomination'] as String?,
      septimaId: id,
    );
  }

  // Otimização: só reconstrói o widget se os dados realmente mudarem
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ViewModel &&
          runtimeType == other.runtimeType &&
          denomination == other.denomination &&
          septimaId == other.septimaId;

  @override
  int get hashCode => denomination.hashCode ^ septimaId.hashCode;
}

class DenominationCard extends StatelessWidget {
  const DenominationCard({super.key});

  // Função auxiliar para copiar texto e mostrar feedback
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ID "$text" copiado para a área de transferência!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, _ViewModel>(
      converter: (store) => _ViewModel.fromStore(store),
      distinct: true, // Garante que só reconstrói se o ViewModel mudar
      builder: (context, viewModel) {
        final hasDenomination = viewModel.denomination != null &&
            viewModel.denomination!.isNotEmpty;
        final hasSeptimaId = viewModel.septimaId != null;

        // Se não houver nenhuma informação para mostrar, retorna um widget vazio
        if (!hasDenomination && !hasSeptimaId) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 16.0), // Espaçamento da bio acima
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
                color: theme.dividerColor.withOpacity(0.5), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha para o Septima ID
              if (hasSeptimaId)
                Row(
                  children: [
                    Icon(
                      Icons.tag, // Ícone de tag/número
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.septimaId!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    // Botão para copiar o ID
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      tooltip: "Copiar ID",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _copyToClipboard(context, viewModel.septimaId!),
                    ),
                  ],
                ),

              // Divisor se ambas as informações existirem
              if (hasSeptimaId && hasDenomination)
                Divider(
                  height: 20,
                  color: theme.dividerColor.withOpacity(0.5),
                ),

              // Linha para a Denominação
              if (hasDenomination)
                Row(
                  children: [
                    Icon(
                      Icons.church_outlined,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.denomination!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
