// lib/pages/user_settings/denomination_selection_modal.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/denomination_model.dart';
import 'package:septima_biblia/services/denomination_service.dart';

class DenominationSelectionModal extends StatefulWidget {
  final DenominationService service;

  const DenominationSelectionModal({super.key, required this.service});

  @override
  _DenominationSelectionModalState createState() =>
      _DenominationSelectionModalState();
}

class _DenominationSelectionModalState
    extends State<DenominationSelectionModal> {
  late Future<List<Denomination>> _denominationsFuture;
  List<Denomination> _filteredDenominations = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _denominationsFuture = widget.service.getAllDenominations();
    _denominationsFuture.then((all) {
      if (mounted) {
        setState(() {
          _filteredDenominations = all;
        });
      }
    });

    _searchController.addListener(_filterList);
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    _denominationsFuture.then((all) {
      if (mounted) {
        setState(() {
          if (query.isEmpty) {
            _filteredDenominations = all;
          } else {
            _filteredDenominations = all.where((denom) {
              return denom.name.toLowerCase().contains(query) ||
                  denom.mainBranch.toLowerCase().contains(query);
            }).toList();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou ramo...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Denomination>>(
                  future: _denominationsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text("Erro ao carregar lista."));
                    }
                    if (snapshot.data == null || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text("Nenhuma denominação encontrada."));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredDenominations.length,
                      itemBuilder: (context, index) {
                        final denom = _filteredDenominations[index];
                        return ListTile(
                          title: Text(denom.name),
                          subtitle: Text(
                            "Ramo: ${denom.mainBranch} • Adeptos: ${denom.memberCount}",
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () {
                            // Retorna a denominação selecionada para a página anterior
                            Navigator.of(context).pop(denom);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
