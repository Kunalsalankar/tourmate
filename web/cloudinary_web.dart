import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;

class CloudinaryWeb {
  static void initialize() {
    // Initialize Cloudinary JS SDK
    js_util.callMethod(js_util.globalThis, 'eval', [
      """
      window.cloudinary = {
        createUploadWidget: function(options, callback) {
          const c = window.cloudinary;
          const optionsStr = JSON.stringify(options);
          const widget = c.createUploadWidget(options, callback);
          return widget;
        }
      };
      """
    ]);

    // Add Cloudinary JS SDK script
    final script = html.ScriptElement()
      ..src = 'https://upload-widget.cloudinary.com/global/all.js'
      ..defer = true;
    html.document.body!.append(script);
  }

  static Future<String> uploadImage(Uint8List imageData, String fileName) async {
    final completer = Completer<String>();
    
    // Convert Uint8List to Blob
    final blob = html.Blob([imageData], 'image/jpeg');
    
    // Create FormData
    final formData = html.FormData();
    formData.append('file', blob, fileName);
    formData.append('upload_preset', 'tourmate_uploads');
    
    // Make the request
    final request = html.HttpRequest();
    request.open('POST', 'https://api.cloudinary.com/v1_1/de3gkk0dh/upload');
    
    request.onLoad.listen((event) {
      if (request.status == 200) {
        final response = json.decode(request.responseText!);
        completer.complete(response['secure_url']);
      } else {
        completer.completeError('Upload failed: ${request.status}');
      }
    });
    
    request.onError.listen((event) {
      completer.completeError('Upload failed: $event');
    });
    
    request.send(formData);
    
    return completer.future;
  }
}
