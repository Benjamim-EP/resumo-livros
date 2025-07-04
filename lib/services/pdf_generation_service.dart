// lib/services/pdf_generation_service.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerationService {
  Future<String> generateBibleChapterPdf({
    required String bookName,
    required int chapterNumber,
    required List<Map<String, dynamic>> sections,
    required Map<String, dynamic> verseData,
    required Map<String, List<Map<String, dynamic>>> commentaries,
  }) async {
    final pdf = pw.Document();

    final font = await pw.Font.ttf(
        await rootBundle.load("assets/fonts/Poppins-Regular.ttf"));
    final fontBold = await pw.Font.ttf(
        await rootBundle.load("assets/fonts/Poppins-Bold.ttf"));
    final fontItalic = await pw.Font.ttf(
        await rootBundle.load("assets/fonts/Poppins-Italic.ttf"));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
            base: font, bold: fontBold, italic: fontItalic),
        header: (context) => _buildHeader(context, bookName, chapterNumber),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildChapterTitle(bookName, chapterNumber),
          ..._buildPdfBody(sections, verseData, commentaries),
        ],
      ),
    );

    return _saveDocument(
      name:
          'septima_biblia_${bookName.replaceAll(' ', '_')}_$chapterNumber.pdf',
      pdf: pdf,
    );
  }

  // --- Widgets Auxiliares ---
  // (Nenhuma mudança no Header, Footer ou ChapterTitle)

  pw.Widget _buildHeader(pw.Context context, String bookName, int chapter) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
      padding: const pw.EdgeInsets.only(bottom: 3.0 * PdfPageFormat.mm),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600)),
      ),
      child: pw.Text(
        '$bookName, Capítulo $chapter - Septima Biblia',
        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8),
      ),
    );
  }

  pw.Widget _buildChapterTitle(String bookName, int chapterNumber) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            bookName,
            style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800),
          ),
          pw.Text(
            'Capítulo $chapterNumber',
            style:
                const pw.TextStyle(fontSize: 22, color: PdfColors.blueGrey500),
          ),
        ],
      ),
    );
  }

  // >>>>>>>>> CORREÇÃO FINAL E MAIS ROBUSTA AQUI <<<<<<<<<
  List<pw.Widget> _buildPdfBody(
    List<Map<String, dynamic>> sections,
    Map<String, dynamic> verseData,
    Map<String, List<Map<String, dynamic>>> commentaries,
  ) {
    List<pw.Widget> contentWidgets = [];
    final nviVerses = verseData['nvi'] as List<String>? ?? [];

    for (var section in sections) {
      final String sectionTitle = section['title'] ?? 'Seção Desconhecida';
      final List<int> verseNumbers =
          (section['verses'] as List?)?.cast<int>() ?? [];

      contentWidgets.add(
        pw.Header(
          level: 1,
          child: pw.Text(sectionTitle,
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal600)),
        ),
      );

      // Renderiza cada versículo como um widget "quebrável"
      for (var vNum in verseNumbers) {
        if (vNum > 0 && vNum <= nviVerses.length) {
          contentWidgets.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 20,
                  child: pw.Text('$vNum',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  child: pw.Paragraph(
                    text: nviVerses[vNum - 1],
                    textAlign: pw.TextAlign.justify,
                  ),
                ),
              ],
            ),
          );
          contentWidgets.add(pw.SizedBox(height: 6));
        }
      }

      contentWidgets.add(pw.SizedBox(height: 10));

      // Busca o comentário
      final String versesRangeStr = verseNumbers.isNotEmpty
          ? (verseNumbers.length == 1
              ? verseNumbers.first.toString()
              : "${verseNumbers.first}-${verseNumbers.last}")
          : "all_verses_in_section";
      final commentaryItems = commentaries[versesRangeStr] ?? [];

      // Renderiza o comentário, se existir
      if (commentaryItems.isNotEmpty) {
        // 1. Adiciona o título e o divisor como widgets separados (sem Container)
        contentWidgets.add(pw.SizedBox(height: 10));
        contentWidgets.add(pw.Text('Comentário da Seção - Matthew Henry',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: PdfColors.blueGrey700)));
        contentWidgets.add(pw.Divider(height: 12, thickness: 0.5));

        // 2. Itera sobre cada item de comentário do banco de dados
        for (var comment in commentaryItems) {
          final String rawText = (comment['traducao'] as String?)?.trim() ??
              (comment['original'] as String?)?.trim() ??
              "";

          if (rawText.isNotEmpty) {
            // 3. CRUCIAL: Divide o texto do comentário por quebras de linha
            final List<String> paragraphs = rawText.split(RegExp(r'\n\s*'));

            // 4. Cria um widget pw.Paragraph para cada parágrafo resultante
            for (var paragraphText in paragraphs) {
              if (paragraphText.isNotEmpty) {
                contentWidgets.add(
                  pw.Paragraph(
                    text: paragraphText,
                    textAlign: pw.TextAlign.justify,
                    style: const pw.TextStyle(color: PdfColors.black),
                    margin: const pw.EdgeInsets.only(bottom: 8.0),
                  ),
                );
              }
            }
          }
        }
      }

      contentWidgets.add(pw.SizedBox(height: 20)); // Espaço final da seção
    }

    return contentWidgets;
  }
  // <<<<<<<<< FIM DA CORREÇÃO

  Future<String> _saveDocument({
    required String name,
    required pw.Document pdf,
  }) async {
    final bytes = await pdf.save();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');

    await file.writeAsBytes(bytes);

    print("PDF salvo em: ${file.path}");
    return file.path;
  }
}
