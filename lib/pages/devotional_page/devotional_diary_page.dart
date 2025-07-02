// lib/pages/devotional_page/devotional_diary_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/devotional_page/daily_devotional_view.dart';
import 'package:septima_biblia/services/notification_service.dart';

class DevotionalDiaryPage extends StatefulWidget {
  const DevotionalDiaryPage({super.key});

  @override
  State<DevotionalDiaryPage> createState() => _DevotionalDiaryPageState();
}

class _DevotionalDiaryPageState extends State<DevotionalDiaryPage> {
  late PageController _pageController;
  DateTime _focusedDate = DateTime.now();

  // We use a fixed large number to represent today's page index in the infinite PageView.
  // This allows scrolling backwards indefinitely.
  static const int _todayPageIndex = 10000;

  @override
  void initState() {
    super.initState();
    // Initialize the page controller to the index representing today.
    _pageController = PageController(initialPage: _todayPageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    // --- MODIFICAÇÃO 1: Definir lastDate como DateTime.now() ---
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(
          DateTime.now().year - 5), // Allow selecting dates up to 5 years ago
      lastDate: DateTime.now(), // Restrict selecting dates beyond today
    );

    if (picked != null && !DateUtils.isSameDay(picked, _focusedDate)) {
      // Calculate the difference in days from today to the picked date.
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      final startOfPickedDate = DateTime(picked.year, picked.month, picked.day);
      final int difference = startOfPickedDate.difference(startOfToday).inDays;

      // Calculate the target page index relative to today's index.
      final int targetPage = _todayPageIndex + difference;

      // Jump to the calculated page.
      _pageController.jumpToPage(targetPage);
      // The onPageChanged will update _focusedDate correctly.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The title now shows the date being viewed
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
          // Calculate the date for the page being scrolled to.
          final today = DateTime.now();
          final startOfToday = DateTime(today.year, today.month, today.day);
          final daysFromToday = page - _todayPageIndex;
          final dateForPage = startOfToday.add(Duration(days: daysFromToday));

          // --- MODIFICAÇÃO 2: Restringir a rolagem para datas futuras ---
          // Check if the calculated date is strictly in the future (after the start of today).
          // Using DateUtils.isSameDay helps handle the time part of DateTime.now() reliably.
          if (dateForPage.isAfter(startOfToday) &&
              !DateUtils.isSameDay(dateForPage, startOfToday)) {
            print(
                "DevotionalDiaryPage: Tentativa de ir para data futura: $dateForPage. Retornando para hoje.");
            // If the new date is in the future, jump the controller back to today's page index.
            // Using Future.microtask ensures the jump happens after the current frame is built,
            // avoiding animation glitches.
            Future.microtask(() {
              if (_pageController.hasClients &&
                  _pageController.page != _todayPageIndex) {
                _pageController.jumpToPage(_todayPageIndex);
              }
            });

            // If the current focused date is NOT already today, update it to today
            if (!DateUtils.isSameDay(_focusedDate, startOfToday)) {
              setState(() {
                _focusedDate = startOfToday;
              });
            }

            // Optionally, show a snackbar to inform the user.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Você só pode acessar dias anteriores ou o dia atual.')),
            );
          } else {
            // If it's today or a past day, allow the state update.
            print("DevotionalDiaryPage: Navegando para data: $dateForPage");
            setState(() {
              _focusedDate = dateForPage;
            });
          }
        },
        itemBuilder: (context, page) {
          // Calculate the date for the current page index.
          final today = DateTime.now();
          final startOfToday = DateTime(today.year, today.month, today.day);
          final daysFromToday = page - _todayPageIndex;
          final dateForPage = startOfToday.add(Duration(days: daysFromToday));

          // Only build the page if it's today or in the past.
          // This check is redundant if onPageChanged already prevents future navigation,
          // but adds an extra layer of safety.
          if (dateForPage.isAfter(startOfToday) &&
              !DateUtils.isSameDay(dateForPage, startOfToday)) {
            // Return an empty container or an error widget if somehow a future page is requested to be built
            return Center(
                child: Text("Conteúdo não disponível para datas futuras.",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontStyle: FontStyle.italic)));
          }

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
