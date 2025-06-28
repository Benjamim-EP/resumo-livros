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

  // Estado para o diário e orações
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _journalController = TextEditingController();
  List<Map<String, dynamic>> _prayerPoints = [];
  bool _isLoadingDiary = true;
  Timer? _debounce;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadAllDataForDate(widget.date);

    // Debounce para salvar o diário automaticamente
    _journalController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(seconds: 2), () {
        _saveJournalEntry();
      });
    });
  }

  @override
  void didUpdateWidget(covariant DailyDevotionalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(widget.date, oldWidget.date)) {
      _saveJournalEntry();
      _loadAllDataForDate(widget.date);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _journalController.dispose();
    super.dispose();
  }

  void _loadAllDataForDate(DateTime date) {
    setState(() {
      _devotionalFuture = _fetchDevotionalFor(date);
      _isLoadingDiary = true;
    });
    _loadDiaryData(date);
  }

  Future<void> _loadDiaryData(DateTime date) async {
    if (_userId == null) {
      setState(() {
        _journalController.text = "Faça login para usar o diário.";
        _prayerPoints = [];
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
        _isLoadingDiary = false;
      });
    }
  }

  Future<void> _saveJournalEntry() async {
    if (_userId == null || !mounted) return;
    await _firestoreService.updateJournalText(
        _userId!, widget.date, _journalController.text);
    print("Diário salvo para ${widget.date}");
  }

  // >>> INÍCIO DA CORREÇÃO 1/2: Renomeada e ajustada <<<
  // Esta função é chamada pelo diálogo.
  Future<void> _addNewPrayerPoint(String text) async {
    if (_userId == null || text.trim().isEmpty) return;
    await _firestoreService.addPrayerPoint(_userId!, widget.date, text.trim());
    _loadDiaryData(widget.date); // Recarrega para mostrar a nova oração
  }
  // >>> FIM DA CORREÇÃO 1/2 <<<

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
    _loadDiaryData(widget.date); // Recarrega
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
              // >>> INÍCIO DA CORREÇÃO 2/2: Chamando a função correta <<<
              _addNewPrayerPoint(prayerController.text);
              // >>> FIM DA CORREÇÃO 2/2 <<<
              Navigator.pop(context);
            },
            child: const Text("Adicionar"),
          ),
        ],
      ),
    );
  }

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
          content: ["Leitura da manhã não encontrada."],
          scripturePassage: '',
          scriptureVerse: ''),
    );

    final eveningReading = allReadings.firstWhere(
      (r) => r.title.contains("Noite, $dayOfMonth de"),
      orElse: () => DevotionalReading(
          title: 'Noite',
          content: ["Leitura da noite não encontrada."],
          scripturePassage: '',
          scriptureVerse: ''),
    );

    return [morningReading, eveningReading];
  }

  @override
  Widget build(BuildContext context) {
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
            final isToday = DateUtils.isSameDay(widget.date, DateTime.now());
            final currentHour = DateTime.now().hour;
            const eveningStartHour = 18;

            List<Widget> devotionalWidgets = [];
            if (isToday) {
              if (currentHour < eveningStartHour) {
                devotionalWidgets.add(DevotionalCard(
                    reading: readings[0],
                    isRead: false,
                    onMarkAsRead: () {},
                    onPlay: () {}));
              } else {
                devotionalWidgets.add(DevotionalCard(
                    reading: readings[1],
                    isRead: false,
                    onMarkAsRead: () {},
                    onPlay: () {}));
              }
            } else {
              devotionalWidgets.add(DevotionalCard(
                  reading: readings[0],
                  isRead: false,
                  onMarkAsRead: () {},
                  onPlay: () {}));
              devotionalWidgets.add(const SizedBox(height: 8));
              devotionalWidgets.add(DevotionalCard(
                  reading: readings[1],
                  isRead: false,
                  onMarkAsRead: () {},
                  onPlay: () {}));
            }
            return Column(children: devotionalWidgets);
          },
        ),

        const SizedBox(height: 24),
        Divider(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        const SizedBox(height: 16),

        // --- SEÇÃO MEU DIÁRIO ---
        Text("Meu Diário", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (_isLoadingDiary)
          const Center(child: CircularProgressIndicator())
        else
          TextField(
            controller: _journalController,
            maxLines: 7,
            enabled: _userId != null,
            decoration: InputDecoration(
              hintText: _userId != null
                  ? "Como foi o seu dia? Que aprendizados você teve?"
                  : "Faça login para usar esta função.",
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
          ),

        const SizedBox(height: 24),

        // --- SEÇÃO PEDIDOS DE ORAÇÃO ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Pedidos de Oração",
                style: Theme.of(context).textTheme.headlineSmall),
            if (_userId != null)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: "Adicionar Pedido",
                onPressed: _showAddPrayerDialog,
              )
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingDiary)
          const Center(child: CircularProgressIndicator())
        else if (_prayerPoints.isEmpty)
          const Text("Nenhum pedido de oração para hoje.",
              style: TextStyle(fontStyle: FontStyle.italic))
        else
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
          )
      ],
    );
  }
}
