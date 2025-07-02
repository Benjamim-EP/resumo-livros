// lib/pages/devotional_page/daily_devotional_view.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:septima_biblia/models/devotional_model.dart';
import 'package:septima_biblia/pages/devotional_page/devotional_card.dart';
import 'package:septima_biblia/pages/devotional_page/promise_search_modal.dart';
import 'package:septima_biblia/services/firestore_service.dart';

class DailyDevotionalView extends StatefulWidget {
  final DateTime date;
  const DailyDevotionalView({super.key, required this.date});

  @override
  State<DailyDevotionalView> createState() => _DailyDevotionalViewState();
}

class _DailyDevotionalViewState extends State<DailyDevotionalView> {
  // Estado para os devocionais (Spurgeon)
  Future<List<DevotionalReading>>? _devotionalFuture;

  // Estado para o diário e orações/promessas
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _journalController = TextEditingController();
  List<Map<String, dynamic>> _prayerPoints = [];
  List<Map<String, dynamic>> _attachedPromises = [];
  bool _isLoadingDiary = true;
  Timer? _debounce;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadAllDataForDate(widget.date);

    // Debounce para salvar o diário automaticamente após o usuário parar de digitar
    _journalController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(seconds: 2), _saveJournalEntry);
    });
  }

  @override
  void didUpdateWidget(covariant DailyDevotionalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(widget.date, oldWidget.date)) {
      _saveJournalEntry(); // Salva a entrada anterior antes de carregar a nova
      _loadAllDataForDate(widget.date);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _journalController.dispose();
    super.dispose();
  }

  // Carrega todos os dados (devocionais e diário) para a data especificada
  void _loadAllDataForDate(DateTime date) {
    setState(() {
      _devotionalFuture = _fetchDevotionalFor(date);
      _isLoadingDiary = true;
    });
    _loadDiaryData(date);
  }

  // Carrega os dados do Firestore (diário, orações, promessas)
  Future<void> _loadDiaryData(DateTime date) async {
    if (_userId == null) {
      setState(() {
        _journalController.text = "Faça login para usar o diário.";
        _prayerPoints = [];
        _attachedPromises = [];
        _isLoadingDiary = false;
      });
      return;
    }
    final entry = await _firestoreService.getDiaryEntry(_userId!, date);
    if (mounted) {
      setState(() {
        _journalController.text = entry?['journalText'] ?? '';
        _prayerPoints =
            List<Map<String, dynamic>>.from(entry?['prayerPoints'] ?? []);
        _attachedPromises =
            List<Map<String, dynamic>>.from(entry?['attachedPromises'] ?? []);
        _isLoadingDiary = false;
      });
    }
  }

  // Salva o texto do diário no Firestore
  Future<void> _saveJournalEntry() async {
    if (_userId == null || !mounted) return;
    await _firestoreService.updateJournalText(
        _userId!, widget.date, _journalController.text);
    print("Diário salvo para ${widget.date}");
  }

  // Funções para gerenciar Pedidos de Oração
  Future<void> _addPrayerPoint(String text) async {
    if (_userId == null || text.trim().isEmpty) return;
    await _firestoreService.addPrayerPoint(_userId!, widget.date, text.trim());
    _loadDiaryData(widget.date);
  }

  Future<void> _updatePrayerPointStatus(int index, bool isAnswered) async {
    if (_userId == null) return;
    Map<String, dynamic> updatedPrayer = Map.from(_prayerPoints[index]);
    updatedPrayer['answered'] = isAnswered;
    await _firestoreService.updatePrayerPoint(
        _userId!, widget.date, index, updatedPrayer);
    _loadDiaryData(widget.date);
  }

  Future<void> _removePrayerPoint(Map<String, dynamic> prayer) async {
    if (_userId == null) return;
    await _firestoreService.removePrayerPoint(_userId!, widget.date, prayer);
    _loadDiaryData(widget.date);
  }

  Future<void> _showAddPrayerDialog() async {
    final TextEditingController prayerController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Novo Pedido de Oração"),
        content: TextField(
          controller: prayerController,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: "Escreva sua oração aqui..."),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              _addPrayerPoint(prayerController.text);
              Navigator.pop(context);
            },
            child: const Text("Adicionar"),
          ),
        ],
      ),
    );
  }

  // Funções para gerenciar Promessas
  Future<void> _addPromiseToDiary(Map<String, String> promise) async {
    if (_userId == null) return;
    await _firestoreService.addPromiseToDiary(_userId!, widget.date, promise);
    _loadDiaryData(widget.date);
  }

  Future<void> _removePromiseFromDiary(Map<String, dynamic> promise) async {
    if (_userId == null) return;
    await _firestoreService.removePromiseFromDiary(
        _userId!, widget.date, promise);
    _loadDiaryData(widget.date);
  }

  void _showPromiseSearchModal() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            PromiseSearchModal(onPromiseSelected: _addPromiseToDiary));
  }

  // Carrega os devocionais do JSON local
  Future<List<DevotionalReading>> _fetchDevotionalFor(DateTime date) async {
    final String jsonString = await rootBundle
        .loadString('assets/devotional/spurgeon_morning_evening.json');
    final List<dynamic> allMonths = json.decode(jsonString);
    String monthName = DateFormat('MMMM', 'pt_BR').format(date);
    monthName = monthName[0].toUpperCase() + monthName.substring(1);
    final dayOfMonth = date.day;
    final monthData = allMonths
        .firstWhere((m) => m['section_title'] == monthName, orElse: () => null);
    if (monthData == null) return [];
    final allReadings = (monthData['readings'] as List)
        .map((r) => DevotionalReading.fromJson(r))
        .toList();
    final morningReading = allReadings.firstWhere(
        (r) => r.title.contains("Manhã, $dayOfMonth de"),
        orElse: () => DevotionalReading(
            title: 'Manhã',
            content: ["Leitura não encontrada."],
            scripturePassage: '',
            scriptureVerse: ''));
    final eveningReading = allReadings.firstWhere(
        (r) => r.title.contains("Noite, $dayOfMonth de"),
        orElse: () => DevotionalReading(
            title: 'Noite',
            content: ["Leitura não encontrada."],
            scripturePassage: '',
            scriptureVerse: ''));
    return [morningReading, eveningReading];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- SEÇÃO DEVOCIONAIS ---
        FutureBuilder<List<DevotionalReading>>(
          future: _devotionalFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text("Devocional não encontrado para esta data.");
            }
            final readings = snapshot.data!;
            final morningReading = readings[0];
            final eveningReading = readings[1];
            final isToday = DateUtils.isSameDay(widget.date, DateTime.now());
            final currentHour = DateTime.now().hour;
            const eveningStartHour = 18;

            List<Widget> devotionalWidgets = [];

            if (isToday) {
              if (currentHour < eveningStartHour) {
                devotionalWidgets.add(DevotionalCard(
                    reading: morningReading,
                    isRead: false,
                    onMarkAsRead: () {},
                    onPlay: () {}));
              } else {
                devotionalWidgets.add(DevotionalCard(
                    reading: morningReading,
                    isRead: false,
                    onMarkAsRead: () {},
                    onPlay: () {}));
                devotionalWidgets.add(const SizedBox(height: 8));
                devotionalWidgets.add(DevotionalCard(
                    reading: eveningReading,
                    isRead: false,
                    onMarkAsRead: () {},
                    onPlay: () {}));
              }
            } else {
              devotionalWidgets.add(DevotionalCard(
                  reading: morningReading,
                  isRead: false,
                  onMarkAsRead: () {},
                  onPlay: () {}));
              devotionalWidgets.add(const SizedBox(height: 8));
              devotionalWidgets.add(DevotionalCard(
                  reading: eveningReading,
                  isRead: false,
                  onMarkAsRead: () {},
                  onPlay: () {}));
            }

            return Column(children: devotionalWidgets);
          },
        ),

        const SizedBox(height: 24),
        Divider(color: theme.dividerColor.withOpacity(0.5)),
        const SizedBox(height: 16),

        // --- SEÇÃO MEU DIÁRIO ---
        Text("Meu Diário", style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (_isLoadingDiary)
          const Center(child: CircularProgressIndicator())
        else
          TextField(
            controller: _journalController,
            maxLines: 4,
            enabled: _userId != null,
            decoration: InputDecoration(
              hintText: _userId != null
                  ? "Como foi o seu dia? Que aprendizados você teve?"
                  : "Faça login para usar esta função.",
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: theme.colorScheme.surface.withOpacity(0.5),
            ),
          ),

        const SizedBox(height: 24),

        // --- SEÇÃO PEDIDOS DE ORAÇÃO E PROMESSAS ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Orações e Promessas", style: theme.textTheme.headlineSmall),
            if (_userId != null)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    tooltip: "Adicionar Pedido de Oração",
                    onPressed: _showAddPrayerDialog,
                    color: theme.colorScheme.primary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.shield_outlined),
                    tooltip: "Anexar Promessa",
                    onPressed: _showPromiseSearchModal,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              )
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingDiary)
          const Center(child: CircularProgressIndicator())
        else if (_prayerPoints.isEmpty && _attachedPromises.isEmpty)
          const Text("Nenhum pedido de oração ou promessa para hoje.",
              style: TextStyle(fontStyle: FontStyle.italic))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lista de Pedidos de Oração
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _prayerPoints.length,
                itemBuilder: (context, index) {
                  final prayer = _prayerPoints[index];
                  final bool isAnswered = prayer['answered'] ?? false;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text(
                        prayer['text'] ?? 'Erro',
                        style: TextStyle(
                            decoration: isAnswered
                                ? TextDecoration.lineThrough
                                : TextDecoration.none),
                      ),
                      leading: Checkbox(
                        value: isAnswered,
                        onChanged: (value) =>
                            _updatePrayerPointStatus(index, value!),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => _removePrayerPoint(prayer),
                      ),
                    ),
                  );
                },
              ),

              // Lista de Promessas Anexadas
              if (_attachedPromises.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text("Promessas para Orar:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attachedPromises.length,
                    itemBuilder: (context, index) {
                      final promise = _attachedPromises[index];
                      return Card(
                        color: theme.colorScheme.secondaryContainer
                            .withOpacity(0.5),
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: Icon(Icons.shield,
                              color: theme.colorScheme.secondary),
                          title: Text('"${promise['text']}"',
                              style:
                                  const TextStyle(fontStyle: FontStyle.italic)),
                          subtitle: Text(promise['reference'],
                              textAlign: TextAlign.right),
                          trailing: IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            tooltip: "Desanexar promessa",
                            onPressed: () => _removePromiseFromDiary(promise),
                          ),
                        ),
                      );
                    }),
              ]
            ],
          )
      ],
    );
  }
}
