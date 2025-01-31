import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class SearchBar2 extends StatelessWidget {
  final String hintText;

  const SearchBar2({super.key, required this.hintText});

  @override
  Widget build(BuildContext context) {
    final TextEditingController queryController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        controller: queryController,
        style: const TextStyle(color: Colors.black), // Texto digitado em preto
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
        ),
        textInputAction: TextInputAction.search, // Define ação de pesquisa no teclado
        onSubmitted: (query) { // Executa a busca ao pressionar "Enter"
          query = query.trim();
          if (query.isNotEmpty) {
            StoreProvider.of<AppState>(context)
                .dispatch(SearchByQueryAction(query: query));
            print("Navegando para a página de resultados...");
            Navigator.pushNamed(context, '/queryResults');
          }
        },
      ),
    );
  }
}
