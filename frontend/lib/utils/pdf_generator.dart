import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

class PdfGenerator {
  static Future<void> generateAndSharePDF(String question, String answer, String timestamp) async {
    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();

      final PdfFont fontTitle = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
      final PdfFont fontText = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final PdfFont fontWatermark = PdfStandardFont(PdfFontFamily.timesRoman, 40, style: PdfFontStyle.italic);

      final Size clientSize = page.getClientSize();

      // Draw Watermark
      final PdfGraphics graphics = page.graphics;
      graphics.save();
      graphics.setTransparency(0.2); // Faint background watermark
      
      PdfTextElement watermark = PdfTextElement(
          text: 'Purna, Kalyan, Chaitu',
          font: fontWatermark,
          brush: PdfSolidBrush(PdfColor(150, 150, 150)));

      // Rotate watermark diagonally
      graphics.translateTransform(clientSize.width / 2, clientSize.height / 2);
      graphics.rotateTransform(-45);
      
      // Draw watermark multiple times across the page invisibly
      watermark.draw(graphics: graphics, bounds: const Rect.fromLTWH(-200, -50, 600, 100));
      watermark.draw(graphics: graphics, bounds: const Rect.fromLTWH(-200, 150, 600, 100));
      watermark.draw(graphics: graphics, bounds: const Rect.fromLTWH(-200, -250, 600, 100));
      graphics.restore();

      // Draw content
      double yOffset = 0;
      
      // Title
      final PdfLayoutResult titleResult = PdfTextElement(text: "Law Lens AI - Legal Breakdown", font: fontTitle)
          .draw(page: page, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 50))!;
      yOffset = titleResult.bounds.bottom + 10;
      
      // Timestamp
      final PdfLayoutResult timeResult = PdfTextElement(text: "Date Generated: $timestamp", font: PdfStandardFont(PdfFontFamily.helvetica, 10))
          .draw(page: page, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, 20))!;
      yOffset = timeResult.bounds.bottom + 20;

      // Question
      final PdfLayoutResult qResult = PdfTextElement(text: "User Query: $question", font: PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold))
          .draw(page: page, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, clientSize.height - yOffset))!;
      yOffset = qResult.bounds.bottom + 20;

      // Answer
      PdfTextElement(text: "AI Response:\n\n$answer", font: fontText)
          .draw(page: page, bounds: Rect.fromLTWH(0, yOffset, clientSize.width, clientSize.height - yOffset));

      // Save file
      final List<int> bytes = await document.save();
      document.dispose();

      final Directory dir = await getApplicationSupportDirectory();
      final String path = '${dir.path}/Law_Lens_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      // Trigger Share / Local Save Dialog
      await SharePlus.instance.share(ShareParams(
          files: [XFile(path)], 
          text: 'Here is your official legal breakdown from Law Lens.'
      ));

    } catch (e) {
      debugPrint("Error generating PDF: $e");
      Fluttertoast.showToast(msg: "Failed to create PDF.", backgroundColor: Colors.redAccent);
    }
  }
}
