import 'package:flutter/material.dart';
import '../components/buttons/tag_button.dart'; // Importa o TagButton

class SwitchTheme2 extends StatefulWidget {
  const SwitchTheme2({Key? key}) : super(key: key);

  @override
  State<SwitchTheme2> createState() => _SwitchThemeState();
}

class _SwitchThemeState extends State<SwitchTheme2> {
  bool isDarkMode = true; // Controle de estado para o tema

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tema Personalizado"),
        actions: [
          Switch(
            value: isDarkMode,
            onChanged: (value) {
              setState(() {
                isDarkMode = value; // Alterna o tema
              });
              // Atualiza o tema da aplicação
              // Recomendo gerenciar o tema dinamicamente no nível superior
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TagButton(
              label: "Botão 1",
              onPressed: () {
                print('button (type 1) pressed');
              },
            ),
            const SizedBox(height: 16),
            TagButton(
              label: "Botão 2",
              onPressed: () {
                print('button (type 1) pressed');
              },
            ),
            const SizedBox(height: 16),
            Text(
              "Ative o modo escuro no switch acima!",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
