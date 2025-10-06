// lib/pages/library_page/components/recommendation_row.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/library_page.dart';
import 'package:septima_biblia/pages/library_page/compact_resource_card.dart';
import 'package:septima_biblia/pages/library_page/resource_detail_modal.dart';
// ✅ 1. IMPORTAÇÃO ADICIONADA
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:septima_biblia/services/custom_page_route.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';

// ViewModel para conectar a linha ao estado Redux
class _ViewModel {
  final bool isPremium;
  _ViewModel({required this.isPremium});

  // ✅ 2. LÓGICA DO VIEWMODEL CORRIGIDA E AUTÔNOMA
  // Agora ele busca o status premium diretamente do estado, sem depender de outro ViewModel.
  static _ViewModel fromStore(Store<AppState> store) {
    bool isCurrentlyPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    if (!isCurrentlyPremium) {
      final userDetails = store.state.userState.userDetails;
      if (userDetails != null) {
        final status = userDetails['subscriptionStatus'] as String?;
        final endDateTimestamp =
            userDetails['subscriptionEndDate'] as Timestamp?;
        if (status == 'active' &&
            endDateTimestamp != null &&
            endDateTimestamp.toDate().isAfter(DateTime.now())) {
          isCurrentlyPremium = true;
        }
      }
    }
    return _ViewModel(isPremium: isCurrentlyPremium);
  }
}

class RecommendationRow extends StatelessWidget {
  final Map<String, dynamic> shelfData;

  const RecommendationRow({super.key, required this.shelfData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title = shelfData['title'] ?? 'Sem Título';
    final List<String> contentIds = List<String>.from(shelfData['items'] ?? []);

    if (contentIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        SizedBox(
          height: 200,
          child: StoreConnector<AppState, _ViewModel>(
            converter: _ViewModel.fromStore,
            builder: (context, viewModel) {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: contentIds.length,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  final contentId = contentIds[index];
                  final fullItemData = allLibraryItems.firstWhere(
                    (item) => item['id'] == contentId,
                    orElse: () => {},
                  );

                  if (fullItemData.isEmpty) {
                    print(
                        "RecommendationRow: Item com ID '$contentId' não encontrado em allLibraryItems.");
                    return const SizedBox.shrink();
                  }

                  final bool isPremiumResource =
                      fullItemData['isFullyPremium'] == true;
                  final String coverPath = fullItemData['coverImagePath'] ?? '';

                  void startReadingAction() {
                    AnalyticsService.instance
                        .logLibraryResourceOpened(fullItemData['title']);
                    if (isPremiumResource && !viewModel.isPremium) {
                      // ✅ 3. A NAVEGAÇÃO AGORA FUNCIONA POR CAUSA DO IMPORT
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const SubscriptionSelectionPage()));
                    } else {
                      interstitialManager.tryShowInterstitial(
                          fromScreen:
                              "Library_Shelf_To_${fullItemData['title']}");
                      Navigator.push(
                        context,
                        FadeScalePageRoute(
                            page: fullItemData['destinationPage']),
                      );
                    }
                  }

                  void openDetailsModal() {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => ResourceDetailModal(
                        itemData: fullItemData,
                        onStartReading: () {
                          Navigator.pop(ctx);
                          startReadingAction();
                        },
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: SizedBox(
                      width: 120,
                      child: CompactResourceCard(
                        title: fullItemData['title'],
                        author: fullItemData['author'],
                        coverImage:
                            coverPath.isNotEmpty ? AssetImage(coverPath) : null,
                        isPremium: isPremiumResource,
                        onCardTap: startReadingAction,
                        onExpandTap: openDetailsModal,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
