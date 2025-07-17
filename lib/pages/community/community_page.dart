// lib/pages/community/community_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/community/forum_home_page.dart'; // Importa a nova página do fórum
import 'package:septima_biblia/pages/community/ranking_tab_view.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 3 abas: Ranking, Salas, Perguntas
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // A AppBar já é fornecida pela MainAppScreen. Esta PreferredSize age como a parte de baixo da AppBar.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color:
              theme.appBarTheme.backgroundColor, // Usa a cor da AppBar do tema
          child: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(text: "Ranking"),
              Tab(text: "Salas"),
              Tab(text: "Perguntas"),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Aba 1: Ranking de usuários
          RankingTabView(),

          // Aba 2: Placeholder para futuras salas de estudo em tempo real
          Placeholder(
            child: Center(
              child: Text("Salas de Estudo (Em Breve!)"),
            ),
          ),

          // Aba 3: O nosso novo Fórum de Perguntas & Respostas
          ForumHomePage(),
        ],
      ),
    );
  }
}
