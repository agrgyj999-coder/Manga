import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
class OcrService {
  OcrService({required TextRecognitionScript script}) : _recognizer = TextRecognizer(script: script);
  final TextRecognizer _recognizer;
  Future<List<RecognizedTextBlock>> recognize(String path) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(path));
    return result.blocks.where((b) => b.text.trim().isNotEmpty).map((b) =>
      RecognizedTextBlock(b.text.trim(), b.boundingBox.left, b.boundingBox.top, b.boundingBox.right, b.boundingBox.bottom)).toList();
  }
  Future<void> dispose() => _recognizer.close();
}
class RecognizedTextBlock {
  const RecognizedTextBlock(this.text, this.left, this.top, this.right, this.bottom);
  final String text;
  final double left, top, right, bottom;
}
