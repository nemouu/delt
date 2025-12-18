import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/receipt_data.dart';
import 'receipt_data_extractor.dart';

/// Service for processing receipt images using ML Kit OCR
/// Singleton pattern for efficient resource management
class ReceiptScannerService {
  static final ReceiptScannerService instance = ReceiptScannerService._();

  ReceiptScannerService._();

  TextRecognizer? _textRecognizer;

  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer();
    return _textRecognizer!;
  }

  /// Process a captured image and extract receipt data
  /// Throws an exception if processing fails
  Future<ReceiptData> processImage(XFile imageFile) async {
    try {
      // Convert XFile to InputImage for ML Kit
      final inputImage = InputImage.fromFilePath(imageFile.path);

      // Run text recognition
      final recognizedText = await _recognizer.processImage(inputImage);

      // Extract raw text
      final rawText = recognizedText.text;

      // If no text detected, return empty ReceiptData
      if (rawText.isEmpty) {
        return ReceiptData(
          rawText: '',
        );
      }

      // Extract structured data using ReceiptDataExtractor
      final receiptData = ReceiptDataExtractor.extractFromText(rawText);

      return receiptData;
    } catch (e) {
      // Rethrow with more context
      throw Exception('Failed to process receipt image: $e');
    }
  }

  /// Dispose of ML Kit resources when done
  /// Call this when the service is no longer needed
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
