import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

class AuthorCoverInformations extends StatelessWidget {
  final String authorId;

  const AuthorCoverInformations({super.key, required this.authorId});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Map<String, dynamic>?>(
      onInit: (store) {
        if (store.state.authorState.authorDetails == null ||
            store.state.authorState.authorDetails!['id'] != authorId) {
          store.dispatch(LoadAuthorDetailsAction(authorId));
        }
      },
      converter: (store) => store.state.authorState.authorDetails,
      builder: (context, authorDetails) {
        if (authorDetails == null) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final String? coverUrl = authorDetails['cover'];
        final String name = authorDetails['nome'] ?? 'Nome desconhecido';
        final String localNascimento =
            authorDetails['localNascimento'] ?? 'Local desconhecido';
        final String nm = authorDetails['nm'] ?? 'Ano desconhecido';

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Imagem de fundo do autor
                // Container(
                //   color: Colors.grey.shade900,
                //   height: 240, // Limita a altura
                //   child: coverUrl != null
                //       ? Image.network(
                //           coverUrl,
                //           width: double.infinity,
                //           height: 240,
                //           fit: BoxFit.cover,
                //           errorBuilder: (context, error, stackTrace) {
                //             return Container(
                //               color: Colors.grey,
                //               child: const Icon(
                //                 Icons.broken_image,
                //                 size: 50,
                //                 color: Colors.white,
                //               ),
                //             );
                //           },
                //         )
                //       : const Icon(
                //           Icons.broken_image,
                //           size: 50,
                //           color: Colors.white,
                //         ),
                // ),
                // // Informações sobrepostas
                Container(
                  color: Colors.black.withOpacity(0.8),
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagem circular do autor
                      CircleAvatar(
                        radius: 58,
                        backgroundImage:
                            coverUrl != null ? NetworkImage(coverUrl) : null,
                        backgroundColor: Colors.grey,
                        child: coverUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      // Detalhes do autor
                      Flexible(
                        fit: FlexFit.loose,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    localNascimento,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    nm,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
