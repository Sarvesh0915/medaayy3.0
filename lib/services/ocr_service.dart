import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Runs entirely on-device — free, works offline, keeps the prescription
/// photo private. The tradeoff (be upfront with users about this): it only
/// extracts raw text, it does NOT know which line is the drug name vs the
/// dosage vs the doctor's signature. `scanImage` returns the raw blocks;
/// turning that into structured {name, dosage, frequency} fields is a
/// separate parsing step you still need to build (simple keyword/regex
/// matching is a reasonable v1; an LLM call is a more robust v2).
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<List<String>> scanImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(inputImage);
    return result.blocks.map((b) => b.text).where((t) => t.trim().isNotEmpty).toList();
  }

  void dispose() => _recognizer.close();
}

/// Shown, non-dismissibly, before a scanned result can be saved.
const String ocrDisclaimer =
    "This was read automatically and may contain mistakes — please check every "
    "medicine name, dose, and timing against the original prescription before saving.";
