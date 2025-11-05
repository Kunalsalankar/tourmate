import 'dart:io';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/comment_model.dart';

class CommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get comments for a specific trip
  Stream<List<Comment>> getComments(String tripId) {
    return _firestore
        .collection('comments')
        .where('tripId', isEqualTo: tripId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Add a new comment
  Future<void> addComment({
    required String tripId,
    required String text,
    File? imageFile,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      String? imageUrl;
      
      if (imageFile != null) {
        try {
          developer.log('Starting image upload to Firebase Storage');
          
          // Create a reference to the location you want to upload to in Firebase Storage
          final ref = FirebaseStorage.instance
              .ref()
              .child('comments')
              .child('${user.uid}')
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
          
          // Start the upload task
          final uploadTask = ref.putFile(
            imageFile,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'uploadedBy': user.uid,
                'tripId': tripId,
              },
            ),
          );

          // Monitor upload progress
          uploadTask.snapshotEvents.listen((taskSnapshot) {
            final progress = (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes * 100).toStringAsFixed(2);
            developer.log('Upload progress: $progress%');
          });

          // Wait for the upload to complete
          final taskSnapshot = await uploadTask.whenComplete(() => null);
          
          // Get the download URL
          imageUrl = await taskSnapshot.ref.getDownloadURL();
          developer.log('Image uploaded successfully: $imageUrl');
          
        } catch (e, stackTrace) {
          developer.log('Error uploading image', error: e, stackTrace: stackTrace);
          // Don't throw the error, just log it and continue without the image
          // You might want to show an error message to the user
        }
      }

      final comment = {
        'userId': user.uid,
        'tripId': tripId,
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'userName': user.displayName ?? 'Anonymous',
        'userPhotoUrl': user.photoURL,
        'platform': Platform.isAndroid ? 'Android' : 
                   Platform.isIOS ? 'iOS' : 
                   kIsWeb ? 'Web' : 'Unknown'
      };
      
      developer.log('Adding comment: ${comment.toString()}');

      await _firestore.collection('comments').add(comment);
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  // Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      await _firestore.collection('comments').doc(commentId).delete();
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }
}
