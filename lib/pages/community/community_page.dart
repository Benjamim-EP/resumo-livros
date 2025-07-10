// lib/pages/community/community_page.dart
import 'package:flutter/material.dart';
// Vamos criar esses arquivos nos próximos passos
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
      // A AppBar já é fornecida pela MainAppScreen, mas precisamos da TabBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color:
              theme.appBarTheme.backgroundColor, // Usa a cor da AppBar do tema
          child: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey,
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
          // Cada aba terá seu próprio widget
          RankingTabView(),
          // RoomsTabView(),
          // QnaTabView(),
        ],
      ),
    );
  }
}
