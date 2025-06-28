// lib/pages/devotional_page/devotional_diary_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/devotional_page/daily_devotional_view.dart';
// >>> INÍCIO DO NOVO IMPORT <<<
import 'package:septima_biblia/services/notification_service.dart';
// >>> FIM DO NOVO IMPORT <<<

class DevotionalDiaryPage extends StatefulWidget {
  const DevotionalDiaryPage({super.key});

  @override
  State<DevotionalDiaryPage> createState() => _DevotionalDiaryPageState();
}

class _DevotionalDiaryPageState extends State<DevotionalDiaryPage> {
  late PageController _pageController;
  DateTime _focusedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // O PageView.builder é infinito, mas começamos na "página" que representa hoje.
    // Usamos um número grande para simular um scroll "infinito" para o passado.
    _pageController = PageController(initialPage: 10000);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(DateTime.now().year - 5), // 5 anos no passado
      lastDate: DateTime(DateTime.now().year + 5), // 5 anos no futuro
    );
    if (picked != null && picked != _focusedDate) {
      // Calcula a diferença em dias para pular para a página correta
      final int todayPage = 10000;
      final int difference = picked.difference(DateTime.now()).inDays;
      final int targetPage = todayPage + difference;

      _pageController.jumpToPage(targetPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // O título agora mostra a data que está sendo visualizada
        title: Text(DateFormat('dd MMMM yyyy', 'pt_BR').format(_focusedDate)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: "Selecionar Data",
            onPressed: () => _selectDate(context),
          )
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          // Atualiza a data focada conforme o usuário desliza
          final today = DateTime.now();
          final daysFromToday = page - 10000;
          setState(() {
            _focusedDate = DateTime(today.year, today.month, today.day)
                .add(Duration(days: daysFromToday));
          });
        },
        itemBuilder: (context, page) {
          // Calcula a data para a página atual
          final today = DateTime.now();
          final daysFromToday = page - 10000;
          final dateForPage = DateTime(today.year, today.month, today.day)
              .add(Duration(days: daysFromToday));

          return DailyDevotionalView(date: dateForPage);
        },
      ),
      // // >>> INÍCIO DA MODIFICAÇÃO: Adicionando o botão de teste <<<
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     // Chama a função de teste do nosso serviço
      //     NotificationService().scheduleTestNotification();

      //     // Mostra um feedback visual para o usuário
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(
      //         content: Text('Notificação de teste agendada para 5 segundos.'),
      //         duration: Duration(seconds: 3),
      //       ),
      //     );
      //   },
      //   icon: const Icon(Icons.notification_add_outlined),
      //   label: const Text("Testar Notif."),
      //   tooltip: "Agendar uma notificação de teste para 5 segundos no futuro.",
      // ),
      // // >>> FIM DA MODIFICAÇÃO <<<
    );
  }
}
