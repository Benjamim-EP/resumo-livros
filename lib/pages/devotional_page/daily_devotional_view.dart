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

  // >>> INÍCIO DA MODIFICAÇÃO: Atualizar a busca quando a data mudar <<<
  @override
  void didUpdateWidget(covariant DailyDevotionalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se a data no widget pai (PageView) mudou, busca o novo devocional.
    if (widget.date != oldWidget.date) {
      setState(() {
        _devotionalFuture = _fetchDevotionalFor(widget.date);
      });
    }
  }
  // >>> FIM DA MODIFICAÇÃO <<<

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
    } catch (e) {
      print("Erro ao carregar devocional para $date: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  "Devocional para ${DateFormat('dd/MM/yyyy', 'pt_BR').format(widget.date)} não encontrado."));
        }

        final readings = snapshot.data!;
        final morningReading = readings[0];
        final eveningReading = readings[1];

        // >>> INÍCIO DA MODIFICAÇÃO: Lógica de exibição baseada no tempo <<<
        final bool isToday = DateUtils.isSameDay(widget.date, DateTime.now());

        if (isToday) {
          // É o dia de hoje, então mostramos um devocional por vez.
          final int currentHour = DateTime.now().hour;
          const int eveningStartHour = 20; // 🕕 20:00 (8 PM)

          if (currentHour < eveningStartHour) {
            // Se for antes das 18h, mostra o da manhã.
            return _buildSingleDevotionalView(
              context: context,
              devotionalToShow: morningReading,
              message:
                  "A reflexão da noite estará disponível a partir das $eveningStartHour:00.",
            );
          } else {
            // Se for 18h ou mais tarde, mostra o da noite.
            return _buildSingleDevotionalView(
              context: context,
              devotionalToShow: eveningReading,
              message:
                  "A reflexão da manhã estará disponível amanhã. Volte sempre!",
            );
          }
        } else {
          // Para dias passados ou futuros, mostra ambos para consulta.
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              DevotionalCard(
                reading: morningReading,
                isRead: false, // Adicionar lógica de "lido" depois
                onMarkAsRead: () {},
                onPlay: () {},
              ),
              DevotionalCard(
                reading: eveningReading,
                isRead: false, // Adicionar lógica de "lido" depois
                onMarkAsRead: () {},
                onPlay: () {},
              ),
            ],
          );
        }
        // >>> FIM DA MODIFICAÇÃO <<<
      },
    );
  }

  // >>> INÍCIO DA MODIFICAÇÃO: Widget auxiliar para a visão de hoje <<<
  /// Constrói a visualização para o dia de hoje, mostrando um único devocional e uma mensagem.
  Widget _buildSingleDevotionalView({
    required BuildContext context,
    required DevotionalReading devotionalToShow,
    required String message,
  }) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DevotionalCard(
            reading: devotionalToShow,
            isRead: false, // Lógica a ser implementada
            onMarkAsRead: () {},
            onPlay: () {},
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // A parte do diário pode continuar aqui se desejar
          // Text("Meu Diário", style: Theme.of(context).textTheme.headlineSmall),
          // const SizedBox(height: 8),
          // const TextField(
          //   maxLines: 7,
          //   decoration: InputDecoration(
          //     hintText: "Como foi o seu dia? Que aprendizados você teve?",
          //     border: OutlineInputBorder(),
          //   ),
          // ),
        ],
      ),
    );
  }
  // >>> FIM DA MODIFICAÇÃO <<<
}
