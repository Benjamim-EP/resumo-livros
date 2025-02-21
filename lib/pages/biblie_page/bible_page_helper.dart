import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BiblePageHelper {
  static Future<Map<String, dynamic>> loadBooksMap() async {
    final String data = await rootBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    return json.decode(data);
  }

  static Future<List<String>> loadChapterContent(
      String bookAbbrev, int chapter, String translation) async {
    try {
      final String data = await rootBundle.loadString(
        'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json',
      );
      return List<String>.from(json.decode(data));
    } catch (e) {
      print('Erro ao carregar o capítulo: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> loadChapterComments(
      String book, int chapter) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("comentario")
          .where("livro", isEqualTo: book)
          .where("capitulo", isEqualTo: chapter.toString())
          .get();

      Map<int, List<Map<String, dynamic>>> commentsMap = {};
      List<Map<String, dynamic>> chapterCommentsList = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        chapterCommentsList.add(data);

        if (data['tags'] != null && data['tags'] is List) {
          for (var tag in data['tags']) {
            if (tag is Map<String, dynamic> &&
                tag['chapter'] == chapter.toString() &&
                tag['verses'] != null &&
                tag['verses'] is List) {
              for (var verse in tag['verses']) {
                final verseNumber = int.tryParse(verse.toString());
                if (verseNumber != null) {
                  commentsMap.putIfAbsent(verseNumber, () => []).add(data);
                }
              }
            }
          }
        }
      }

      chapterCommentsList.sort((a, b) {
        final numA = int.tryParse(a['topic_number']?.toString() ?? '0') ?? 0;
        final numB = int.tryParse(b['topic_number']?.toString() ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

      return {
        'chapterComments': chapterCommentsList,
        'verseComments': commentsMap,
      };
    } catch (e) {
      print("Erro ao carregar comentários: $e");
      return {'chapterComments': [], 'verseComments': {}};
    }
  }
}
