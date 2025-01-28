import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';

class TribeSelectionPage extends StatelessWidget {
  final Map<String, String> tribos;

  TribeSelectionPage({Key? key, required this.tribos}) : super(key: key);

  final Map<String, String> _triboImageMap = {
    'Aser': 'assets/images/tribos/aser.webp',
    'Benjamim': 'assets/images/tribos/benjamim.webp',
    'Dã': 'assets/images/tribos/da.webp',
    'Gade': 'assets/images/tribos/gade.webp',
    'Issacar': 'assets/images/tribos/issacar.webp',
    'José (Efraim e Manassés)': 'assets/images/tribos/jose.webp',
    'Judá': 'assets/images/tribos/juda.webp',
    'Levi': 'assets/images/tribos/levi.webp',
    'Naftali': 'assets/images/tribos/naftali.webp',
    'Rúben': 'assets/images/tribos/ruben.webp',
    'Simeão': 'assets/images/tribos/simeao.webp',
    'Zebulom': 'assets/images/tribos/zebulom.webp',
  };

  final Map<String, String> _triboDescriptionMap = {
    'Rúben': '("Veja, um filho!") - Água',
    'Simeão': '("Ouvir") - Portão',
    'Levi': '("Apegado") - Peitoral do sumo sacerdote',
    'Judá': '("Louvado") - Leão',
    'Dã': '("Julgar") - Serpente',
    'Naftali': '("Minha luta") - Cervo',
    'Gade': '("Boa fortuna"/"Guerreiro") - Tendas',
    'Aser': '("Feliz") - Árvore',
    'Issacar': '("Há uma recompensa") - Burro',
    'Zebulom': '("Morada") - Navio',
    'José (Efraim e Manassés)': '("Ele aumentará") - Espigas de trigo',
    'Benjamim': '("Filho da mão direita") - Lobo',
  };

  Future<void> _selectTribe(BuildContext context, String triboName) async {
    final store = StoreProvider.of<AppState>(context);
    final userId = store.state.userState.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro: usuário não autenticado.'),
        ),
      );
      return;
    }

    try {
      // Atualiza o Firestore com a tribo escolhida e firstLogin
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userDoc.update({
        'Tribo': triboName,
        'firstLogin': false,
      });

      // Despacha a ação para buscar tópicos com os userFeatures
      final userFeatures = store.state.userState.userFeatures;
      if (userFeatures != null) {
        store.dispatch(FetchTribeTopicsAction(userFeatures));
      }

      // Navega para a página principal
      Navigator.pushNamed(context, '/mainAppScreen');
    } catch (e) {
      print('Erro ao salvar tribo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar tribo: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A1A),
      appBar: AppBar(
        title: const Text('Selecione sua Tribo'),
        backgroundColor: const Color(0xFF232538),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Baseado nas suas características, sugerimos as seguintes tribos:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal, // Rolagem horizontal
                itemCount: tribos.length,
                itemBuilder: (context, index) {
                  final triboName = tribos.keys.elementAt(index);
                  final motivo = tribos[triboName]!;
                  final imagePath = _triboImageMap[triboName] ?? '';
                  final description = _triboDescriptionMap[triboName] ?? '';

                  return Container(
                    width: 250, // Largura fixa para cada card
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Card(
                      color: const Color(0xFF232538),
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Imagem da tribo
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: imagePath.isNotEmpty
                                  ? Image.asset(
                                      imagePath,
                                      height: 160,
                                      width: 224,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 120,
                                      width: double.infinity,
                                      color: Colors.grey,
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            // Nome da tribo
                            Text(
                              triboName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            // Descrição da tribo
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            // Motivo
                            Text(
                              motivo,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              maxLines: 10,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const Spacer(),
                            // Botão de seleção
                            ElevatedButton(
                              onPressed: () => _selectTribe(context, triboName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Selecionar',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
