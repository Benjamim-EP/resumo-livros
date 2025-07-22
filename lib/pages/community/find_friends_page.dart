// lib/pages/community/find_friends_page.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/community/public_profile_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class FindFriendsPage extends StatefulWidget {
  const FindFriendsPage({super.key});

  @override
  State<FindFriendsPage> createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: "southamerica-east1");

  // Estado da UI
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSearchMode = false;
  String? _errorMessage;

  // Gerenciamento de dados e paginação
  List<Map<String, dynamic>> _userList = [];
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialRandomUsers();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        !_isSearchMode &&
        _hasMore) {
      _fetchMoreRandomUsers();
    }
  }

  Future<void> _fetchInitialRandomUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _userList = [];
      _hasMore = true;
    });
    try {
      final callable = _functions.httpsCallable('getRandomUsers');
      final result = await callable.call<Map<String, dynamic>>({'limit': 20});
      if (mounted) {
        final List<dynamic> users = result.data['users'] ?? [];
        setState(() {
          _userList =
              users.map((user) => Map<String, dynamic>.from(user)).toList();
          _hasMore = users.length == 20;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Erro ao buscar usuários.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreRandomUsers() async {
    setState(() => _isLoadingMore = true);
    try {
      final callable = _functions.httpsCallable('getRandomUsers');
      final result = await callable.call<Map<String, dynamic>>({
        'limit': 20,
        'startAfter': _userList.last['userId'],
      });
      if (mounted) {
        final List<dynamic> newUsers = result.data['users'] ?? [];
        setState(() {
          _userList
              .addAll(newUsers.map((user) => Map<String, dynamic>.from(user)));
          _hasMore = newUsers.length == 20;
        });
      }
    } catch (e) {
      // Silenciosamente ignora erros de paginação para não interromper a UX
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _isSearchMode = true;
      _errorMessage = null;
      _userList = [];
    });

    try {
      final callable = _functions.httpsCallable('findUsers');
      final result =
          await callable.call<Map<String, dynamic>>({'query': query});
      if (mounted) {
        final List<dynamic> users = result.data['users'] ?? [];
        setState(() {
          _userList =
              users.map((user) => Map<String, dynamic>.from(user)).toList();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted)
        setState(() => _errorMessage = e.message ?? "Erro na busca.");
    } catch (e) {
      if (mounted)
        setState(() => _errorMessage = "Ocorreu um erro inesperado.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearchMode = false;
      _errorMessage = null;
    });
    _fetchInitialRandomUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Encontrar Pessoas")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Buscar por Nome ou ID Septima",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
              onSubmitted: (_) => _searchUsers(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
          child: Text(_errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)));
    }
    if (_userList.isEmpty) {
      return Center(
          child: Text(_isSearchMode
              ? "Nenhum usuário encontrado."
              : "Nenhum usuário para mostrar."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            _isSearchMode ? "Resultados da Busca" : "Explore Usuários",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _userList.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _userList.length) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator()));
              }
              final user = _userList[index];
              return _buildUserResultCard(user);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserResultCard(Map<String, dynamic> userData) {
    final String? denomination = userData['denomination'];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              (userData['photoURL'] != null && userData['photoURL']!.isNotEmpty)
                  ? NetworkImage(userData['photoURL']!)
                  : null,
          child: (userData['photoURL'] == null || userData['photoURL']!.isEmpty)
              ? Text(userData['nome']?[0] ?? '?')
              : null,
        ),
        title: Text(userData['nome'] ?? 'Usuário Desconhecido'),
        subtitle: denomination != null && denomination.isNotEmpty
            ? Text(denomination, style: Theme.of(context).textTheme.bodySmall)
            : null,
        onTap: () {
          Navigator.push(
            context,
            FadeScalePageRoute(
              page: PublicProfilePage(
                userId: userData['userId'],
                initialUserData: userData,
              ),
            ),
          );
        },
      ),
    );
  }
}
