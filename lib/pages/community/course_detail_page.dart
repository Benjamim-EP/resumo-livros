// lib/pages/community/course_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/community/chapter_detail_page.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';

// ViewModel para obter o status de assinatura do Redux
class _ViewModel {
  final bool isPremium;
  _ViewModel({required this.isPremium});
  static _ViewModel fromStore(Store<AppState> store) {
    bool isConsideredPremium = false;

    // 1. Verifica o estado oficial da assinatura
    if (store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive) {
      isConsideredPremium = true;
    } else {
      // 2. Como fallback, verifica os dados brutos do Firestore no userDetails
      final userDetails = store.state.userState.userDetails;
      if (userDetails != null) {
        final statusString = userDetails['subscriptionStatus'] as String?;
        final endDate =
            (userDetails['subscriptionEndDate'] as Timestamp?)?.toDate();

        if (statusString == 'active' &&
            endDate != null &&
            endDate.isAfter(DateTime.now())) {
          isConsideredPremium = true;
        }
      }
    }

    return _ViewModel(
      isPremium: isConsideredPremium,
    );
  }
}

class CourseDetailPage extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseDetailPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  // Estado para armazenar os dados do preview
  bool _isLoadingPreviewData = true;
  String? _firstPartId;
  String? _firstChapterId;

  @override
  void initState() {
    super.initState();
    _loadPreviewData();
  }

  /// Carrega os IDs da primeira parte e do primeiro capítulo para saber o que é gratuito.
  Future<void> _loadPreviewData() async {
    try {
      final courseDoc = await FirebaseFirestore.instance
          .collection('cursos')
          .doc(widget.courseId)
          .get();

      if (courseDoc.exists) {
        final courseData = courseDoc.data() as Map<String, dynamic>;
        final List<String> parts =
            List<String>.from(courseData['partes'] ?? []);

        if (parts.isNotEmpty) {
          final firstPart = parts.first;
          final chaptersSnapshot = await FirebaseFirestore.instance
              .collection('cursos')
              .doc(widget.courseId)
              .collection(firstPart)
              .get();

          if (chaptersSnapshot.docs.isNotEmpty) {
            // Ordena os capítulos pelo ID para garantir que "1-..." venha primeiro
            final sortedChapters = chaptersSnapshot.docs
              ..sort((a, b) => a.id.compareTo(b.id));
            setState(() {
              _firstPartId = firstPart;
              _firstChapterId = sortedChapters.first.id;
            });
          }
        }
      }
    } catch (e) {
      print("Erro ao carregar dados de preview do curso: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingPreviewData = false);
      }
    }
  }

  /// Mostra um diálogo incentivando o usuário a assinar.
  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conteúdo Premium 👑'),
        content: const Text(
            'Este capítulo faz parte do conteúdo exclusivo para assinantes. Desbloqueie este e todos os outros cursos com o Septima Premium!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Agora não')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Fecha o diálogo
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SubscriptionSelectionPage()));
            },
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseTitle),
      ),
      body: StoreConnector<AppState, _ViewModel>(
        converter: (store) => _ViewModel.fromStore(store),
        builder: (context, vm) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('cursos')
                .doc(widget.courseId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _isLoadingPreviewData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                    child: Text("Detalhes do curso não encontrados."));
              }

              final courseData = snapshot.data!.data() as Map<String, dynamic>;
              final List<String> parts =
                  List<String>.from(courseData['partes'] ?? []);

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: parts.length,
                itemBuilder: (context, index) {
                  final partId = parts[index];
                  // Passamos o ViewModel (com status premium) para o método que constrói a lista de capítulos
                  return _buildPartExpansionTile(context, partId, vm);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPartExpansionTile(
      BuildContext context, String partId, _ViewModel vm) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        title: Text(partId, style: theme.textTheme.titleLarge),
        children: [_buildChapterList(context, partId, vm)],
      ),
    );
  }

  Widget _buildChapterList(BuildContext context, String partId, _ViewModel vm) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cursos')
          .doc(widget.courseId)
          .collection(partId)
          .orderBy(FieldPath.documentId) // Ordena pelo ID do capítulo
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.update,
                    size: 32,
                    color: theme.iconTheme.color?.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Capítulos em breve...",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final chapters = snapshot.data!.docs;
        return Column(
          children: chapters.map((doc) {
            // --- A LÓGICA PRINCIPAL ESTÁ AQUI ---
            final bool isPreviewChapter =
                (partId == _firstPartId && doc.id == _firstChapterId);
            final bool isLocked = !vm.isPremium && !isPreviewChapter;
            print("User is ${vm.isPremium ? 'premium' : 'not premium'}");

            return ListTile(
              title: Text(doc.id),
              // Diminui a opacidade do título se estiver bloqueado
              textColor: isLocked
                  ? theme.textTheme.bodyLarge?.color?.withOpacity(0.5)
                  : null,
              trailing: isLocked
                  // Mostra um ícone de cadeado/premium se estiver bloqueado
                  ? Icon(Icons.workspace_premium_outlined,
                      color: Colors.amber.shade700)
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                if (isLocked) {
                  // Se bloqueado, mostra o diálogo para assinar
                  _showPremiumDialog(context);
                } else {
                  // Se liberado (premium ou preview), navega para a página do capítulo
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChapterDetailPage(
                        courseId: widget.courseId,
                        partId: partId,
                        chapterId: doc.id,
                      ),
                    ),
                  );
                }
              },
            );
          }).toList(),
        );
      },
    );
  }
}
