+--import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CloudinaryService {
  // Cloudinary configuration
  static const String _cloudName = 'de3gkk0dh';
  static const String _apiKey = '245225161758312';
  static const String _uploadPreset = 'tourmate_uploads';
  
  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cacheMaxAge: const Duration(days: 30),
  );

  static Future<String> uploadImage(File file) async {
    try {
      if (kIsWeb) {
        // For web, read the file as bytes and use the web upload method
        final bytes = await file.readAsBytes();
        return await _uploadToCloudinary(bytes, 'mobile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      } else {
        // For mobile, use the standard file upload
        final response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            file.path,
            folder: 'tourmate/comments',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        return response.secureUrl!;
      }
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  static Future<String> uploadImageFromWeb(Uint8List imageData) async {
    try {
      return await _uploadToCloudinary(imageData, 'web_${DateTime.now().millisecondsSinceEpoch}.jpg');
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
  
  static Future<String> _uploadToCloudinary(Uint8List bytes, String filename) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/upload');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['api_key'] = _apiKey;
      
      // Add file to request
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['secure_url'];
      } else {
        throw Exception('Upload failed with status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
