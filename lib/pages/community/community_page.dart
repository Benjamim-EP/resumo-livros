// lib/pages/community/community_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/community/BookClubListPage.dart';
import 'package:septima_biblia/pages/community/course_list_page.dart';
import 'package:septima_biblia/pages/community/forum_home_page.dart';
import 'package:septima_biblia/pages/community/ranking_tab_view.dart';
// <<< 1. IMPORTAR A NOVA PÁGINA DA LISTA DE CURSOS >>>

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
    // <<< 2. ALTERAR O NÚMERO DE ABAS PARA 4 >>>
    _tabController = TabController(length: 4, vsync: this);
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: theme.appBarTheme.backgroundColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              // <<< 3. ATUALIZAR AS LABELS DAS ABAS >>>
              Tab(text: "Ranking"),
              Tab(text: "Clube do Livro"),
              Tab(text: "Cursos"), // Nova aba
              Tab(text: "Fórum"),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // <<< 4. ADICIONAR O WIDGET DA NOVA PÁGINA >>>
          RankingTabView(),
          BookClubListPage(),
          CourseListPage(), // Novo widget
          ForumHomePage(),
        ],
      ),
    );
  }
}
