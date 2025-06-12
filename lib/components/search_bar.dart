import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/components/login_required.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

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
        textInputAction:
            TextInputAction.search, // Define ação de pesquisa no teclado
        onSubmitted: (query) {
          query = query.trim();
          if (query.isNotEmpty) {
            final storeInstance = StoreProvider.of<AppState>(context,
                listen: false); // Mude para storeInstance
            // if (storeInstance.state.userState.isGuestUser) {
            //   showLoginRequiredDialog(context, featureName: "a pesquisa");
            // } else {
            storeInstance.dispatch(
                SearchByQueryAction(query: query)); // Use storeInstance
            print("Navegando para a página de resultados...");
            Navigator.pushNamed(context, '/queryResults');
            //}
          }
        },
      ),
    );
  }
}
