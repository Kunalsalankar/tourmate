import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';

class WebFileService {
  static Future<Uint8List?> pickImage() async {
    final completer = Completer<Uint8List?>();
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;
    
    void handleFile(html.File file) async {
      try {
        final reader = html.FileReader();
        
        reader.onLoad.listen((event) {
          try {
            if (reader.result is Uint8List) {
              completer.complete(reader.result as Uint8List);
            } else if (reader.result is String) {
              // Handle data URL
              final data = (reader.result as String).split(',').last;
              completer.complete(base64Decode(data));
            } else {
              completer.completeError('Unsupported file format');
            }
          } catch (e) {
            completer.completeError('Error processing file: $e');
          }
        });
        
        reader.onError.listen((error) {
          completer.completeError(error);
        });
        
        // Read as data URL for better compatibility
        reader.readAsDataUrl(file);
      } catch (e) {
        completer.completeError('Failed to read file: $e');
      }
    }

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }
      handleFile(files.first);
    });

    // Trigger the file picker
    input.click();

    try {
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('File selection timed out');
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}
