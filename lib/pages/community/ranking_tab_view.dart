// lib/pages/community/ranking_tab_view.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';

// Componentes da UI
import 'package:septima_biblia/pages/community/podium_widget.dart';
import 'package:septima_biblia/pages/community/ranking_list_item.dart';
import 'package:septima_biblia/pages/community/user_ranking_card.dart';

// Modelo de Dados para o Ranking
class RankingUser {
  final String id;
  final String name;
  final String? photoURL;
  final double rankingScore;
  final int? previousRank; // <<< NOVO CAMPO (pode ser nulo)

  RankingUser({
    required this.id,
    required this.name,
    this.photoURL,
    required this.rankingScore,
    this.previousRank, // <<< NOVO PARÂMETRO
  });

  factory RankingUser.fromFirestore(
      DocumentSnapshot userProgressDoc, DocumentSnapshot userDoc) {
    final progressData = userProgressDoc.data() as Map<String, dynamic>? ?? {};
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    return RankingUser(
      id: userProgressDoc.id,
      name: userData['nome'] ?? 'Anônimo',
      photoURL: userData['photoURL'],
      rankingScore: (progressData['rankingScore'] as num?)?.toDouble() ?? 0.0,
      previousRank: userData['previousRank'] as int?, // <<< LÊ O NOVO CAMPO
    );
  }

  // Construtor para dados artificiais (mock) do JSON
  factory RankingUser.fromMock(Map<String, dynamic> mockData) {
    return RankingUser(
      id: mockData['id'] ?? 'mock_id',
      name: mockData['name'] ?? 'Usuário Fictício',
      photoURL: mockData['photoURL'],
      rankingScore: (mockData['rankingScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ViewModel para obter os dados do usuário logado do Redux
class _RankingViewModel {
  final String? loggedInUserId;
  final String? loggedInUserName;
  final String? loggedInUserPhotoUrl;

  _RankingViewModel({
    this.loggedInUserId,
    this.loggedInUserName,
    this.loggedInUserPhotoUrl,
  });

  static _RankingViewModel fromStore(Store<AppState> store) {
    return _RankingViewModel(
      loggedInUserId: store.state.userState.userId,
      loggedInUserName: store.state.userState.userDetails?['nome'],
      loggedInUserPhotoUrl: store.state.userState.userDetails?['photoURL'],
    );
  }
}

class RankingTabView extends StatefulWidget {
  const RankingTabView({super.key});

  @override
  State<RankingTabView> createState() => _RankingTabViewState();
}

class _RankingTabViewState extends State<RankingTabView> {
  late Future<List<RankingUser>> _rankingFuture;

  @override
  void initState() {
    super.initState();
    _rankingFuture = _fetchAndFillRanking();
  }

  Future<List<RankingUser>> _fetchAndFillRanking() async {
    List<RankingUser> realUsers = [];
    try {
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('userBibleProgress')
          .orderBy('rankingScore', descending: true)
          .limit(100)
          .get();

      if (progressSnapshot.docs.isNotEmpty) {
        final userIds = progressSnapshot.docs.map((doc) => doc.id).toList();

        Map<String, DocumentSnapshot> userDocsMap = {};
        for (var i = 0; i < userIds.length; i += 30) {
          final chunk = userIds.sublist(
              i, i + 30 > userIds.length ? userIds.length : i + 30);
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var doc in usersSnapshot.docs) {
            userDocsMap[doc.id] = doc;
          }
        }

        for (var progressDoc in progressSnapshot.docs) {
          final userDoc = userDocsMap[progressDoc.id];
          if (userDoc != null) {
            realUsers.add(RankingUser.fromFirestore(progressDoc, userDoc));
          }
        }
      }
    } catch (e) {
      print("Erro ao buscar ranking real (usando mock como fallback): $e");
    }

    // Se tivermos menos de 30 usuários reais, completa com mock data
    if (realUsers.length < 30) {
      try {
        final String jsonString =
            await rootBundle.loadString('assets/mock_data/ranking_mock.json');
        final List<dynamic> mockDataList = json.decode(jsonString);
        final List<RankingUser> mockUsers =
            mockDataList.map((data) => RankingUser.fromMock(data)).toList();

        final realUserIds = realUsers.map((u) => u.id).toSet();

        for (var mockUser in mockUsers) {
          if (realUsers.length >= 30) break;
          if (!realUserIds.contains(mockUser.id)) {
            realUsers.add(mockUser);
          }
        }
      } catch (e) {
        print("Erro ao carregar dados mock de ranking: $e");
      }
    }

    realUsers.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

    return realUsers;
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _RankingViewModel>(
      converter: (store) => _RankingViewModel.fromStore(store),
      builder: (context, viewModel) {
        return FutureBuilder<List<RankingUser>>(
          future: _rankingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Erro ao carregar o ranking: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text("Ninguém no ranking ainda. Seja o primeiro!"));
            }

            final allUsers = snapshot.data!;

            // Lógica para encontrar o usuário logado e sua posição
            RankingUser? loggedInUserRankingData;
            int? loggedInUserRank;
            final userIndex = allUsers
                .indexWhere((user) => user.id == viewModel.loggedInUserId);

            if (userIndex != -1) {
              loggedInUserRankingData = allUsers[userIndex];
              loggedInUserRank = userIndex + 1;
            }

            final podiumUsers = allUsers.take(3).toList();
            final listUsers =
                allUsers.length > 3 ? allUsers.sublist(3) : <RankingUser>[];

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _rankingFuture = _fetchAndFillRanking();
                });
              },
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                children: [
                  if (podiumUsers.isNotEmpty) PodiumWidget(users: podiumUsers),

                  const SizedBox(height: 40),

                  // Card do usuário atual
                  if (loggedInUserRankingData != null)
                    UserRankingCard(
                      name: loggedInUserRankingData.name,
                      score: loggedInUserRankingData.rankingScore
                          .toStringAsFixed(0),
                      rank: loggedInUserRank!,
                      photoUrl: loggedInUserRankingData.photoURL,
                    )
                  else
                    UserRankingCard(
                      name: viewModel.loggedInUserName ?? "Você",
                      score: "0",
                      rank: 0,
                      photoUrl: viewModel.loggedInUserPhotoUrl,
                    ),

                  const SizedBox(height: 24),

                  if (listUsers.isNotEmpty)
                    Text(
                      "Top 100 Leitores",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                  // Restante da lista
                  if (listUsers.isNotEmpty)
                    ...List.generate(listUsers.length, (index) {
                      final user = listUsers[index];
                      final rank = index + 4;

                      // Não mostra o usuário logado novamente na lista
                      if (user.id == viewModel.loggedInUserId) {
                        return const SizedBox.shrink();
                      }

                      return RankingListItem(
                        rank: rank,
                        name: user.name,
                        photoUrl: user.photoURL,
                        score: user.rankingScore.toStringAsFixed(0),
                        previousRank: user.previousRank,
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
