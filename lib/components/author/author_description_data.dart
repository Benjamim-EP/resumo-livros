import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class AuthorDescriptionData extends StatelessWidget {
  const AuthorDescriptionData({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Map<String, dynamic>?>(
      converter: (store) => store.state.authorState.authorDetails,
      builder: (context, authorDetails) {
        if (authorDetails == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final descricao =
            authorDetails['descricao'] ?? 'Descrição não disponível';
        final nLivros = authorDetails['n_livros'] ?? 0;
        final curtidas = authorDetails['curtidas'] ?? 0;
        final leitoresSemanais = authorDetails['leitoresSemanais'] ?? 0;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                descricao,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  InfoButton(
                    icon: Icons.book,
                    label: '$nLivros Livros',
                    color: Colors.lightBlueAccent,
                  ),
                  InfoButton(
                    icon: Icons.favorite,
                    label: '$curtidas',
                    color: Colors.redAccent,
                  ),
                  InfoButton(
                    icon: Icons.group,
                    label: '$leitoresSemanais',
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class InfoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const InfoButton({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8.0),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
