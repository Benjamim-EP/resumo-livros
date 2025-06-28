// lib/pages/devotional_page/daily_devotional_view.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:septima_biblia/models/devotional_model.dart';
import 'package:septima_biblia/pages/devotional_page/devotional_card.dart';

class DailyDevotionalView extends StatefulWidget {
  final DateTime date;

  const DailyDevotionalView({super.key, required this.date});

  @override
  State<DailyDevotionalView> createState() => _DailyDevotionalViewState();
}

class _DailyDevotionalViewState extends State<DailyDevotionalView> {
  Future<List<DevotionalReading>>? _devotionalFuture;

  @override
  void initState() {
    super.initState();
    _devotionalFuture = _fetchDevotionalFor(widget.date);
  }

  Future<List<DevotionalReading>> _fetchDevotionalFor(DateTime date) async {
    try {
      final String jsonString = await rootBundle
          .loadString('assets/devotional/spurgeon_morning_evening.json');
      final List<dynamic> allMonths = json.decode(jsonString);

      String monthName = DateFormat('MMMM', 'pt_BR').format(date);
      monthName = monthName[0].toUpperCase() + monthName.substring(1);
      final dayOfMonth = date.day;

      final monthData = allMonths.firstWhere(
          (m) => m['section_title'] == monthName,
          orElse: () => null);

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
            scriptureVerse: ''),
      );

      final eveningReading = allReadings.firstWhere(
        (r) => r.title.contains("Noite, $dayOfMonth de"),
        orElse: () => DevotionalReading(
            title: 'Noite',
            content: ["Leitura não encontrada."],
            scripturePassage: '',
            scriptureVerse: ''),
      );

      return [morningReading, eveningReading];
    } catch (e) {
      print("Erro ao carregar devocional para $date: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DevotionalReading>>(
      future: _devotionalFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text("Erro ao carregar devocional: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.length < 2) {
          return Center(
              child: Text(
                  "Devocional para ${DateFormat('dd/MM/yyyy').format(widget.date)} não encontrado."));
        }

        final readings = snapshot.data!;
        final morningReading = readings[0];
        final eveningReading = readings[1];

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // O título agora é o card individual
            DevotionalCard(
              reading: morningReading,
              isRead: false,
              onMarkAsRead: () {},
              onPlay: () {},
            ),
            DevotionalCard(
              reading: eveningReading,
              isRead: false,
              onMarkAsRead: () {},
              onPlay: () {},
            ),
            const SizedBox(height: 24),
            Text("Meu Diário",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const TextField(
              maxLines: 7,
              decoration: InputDecoration(
                hintText: "Como foi o seu dia? Que aprendizados você teve?",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text("Pedidos de Oração",
                style: Theme.of(context).textTheme.headlineSmall),
            // UI para orações...
          ],
        );
      },
    );
  }
}
