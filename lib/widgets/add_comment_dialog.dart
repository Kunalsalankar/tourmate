import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/colors.dart';
import '../firebase_options.dart';
import '../core/models/location_comment_model.dart';
import '../core/repositories/location_comment_repository.dart';

/// Dialog for adding location comments during a trip
class AddCommentDialog extends StatefulWidget {
  final LatLng currentLocation;
  final String userId;
  final String userName;
  final String? tripId;

  const AddCommentDialog({
    super.key,
    required this.currentLocation,
    required this.userId,
    required this.userName,
    this.tripId,
  });

  @override
  State<AddCommentDialog> createState() => _AddCommentDialogState();
}

class _AddCommentDialogState extends State<AddCommentDialog> {
  final TextEditingController _commentController = TextEditingController();
  final LocationCommentRepository _repository = LocationCommentRepository();
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _webImage;
  
  bool _isSubmitting = false;
  String? _selectedTag;
  
  final List<String> _availableTags = [
    'Traffic',
    'Scenic View',
    'Food & Drink',
    'Rest Stop',
    'Fuel Station',
    'Parking',
    'Accident',
    'Road Work',
    'Police',
    'Landmark',
    'Other',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _pickedImage = image;
            _webImage = bytes;
          });
        } else {
          setState(() {
            _pickedImage = image;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _pickedImage = image;
            _webImage = bytes;
          });
        } else {
          setState(() {
            _pickedImage = image;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick from gallery: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? photoUrl;

      // If a photo was selected, upload to Firebase Storage
      if (_pickedImage != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('You must be signed in to upload a photo');
        }
        final file = File(_pickedImage!.path);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
        // Debug bucket and destination path
        // ignore: avoid_print
        print('[AddCommentDialog] Upload bucket: $bucket');
        final storage = FirebaseStorage.instanceFor(app: Firebase.app(), bucket: bucket);
        final rootRef = storage.refFromURL('gs://$bucket');
        final fullRef = rootRef.child('comment_photos').child(user.uid).child(fileName);
        // ignore: avoid_print
        print('[AddCommentDialog] Upload path: ${fullRef.fullPath}');
        try {
          final task = await fullRef.putFile(
            file,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          photoUrl = await task.ref.getDownloadURL();
        } on FirebaseException catch (e) {
          // ignore: avoid_print
          print('[AddCommentDialog] Upload failed: code=${e.code} message=${e.message}');
          rethrow;
        }
      }

      final comment = LocationCommentModel(
        uid: widget.userId,
        userName: widget.userName,
        comment: _commentController.text.trim(),
        lat: widget.currentLocation.latitude,
        lng: widget.currentLocation.longitude,
        timestamp: DateTime.now(),
        tripId: widget.tripId,
        tags: _selectedTag != null ? [_selectedTag!] : null,
        photoUrl: photoUrl,
      );

      final commentId = await _repository.addComment(comment);

      if (!mounted) return;

      if (commentId != null) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Comment added successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Failed to add comment');
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding comment: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.comment,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Comment',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Share your journey experience',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Location info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location: ${widget.currentLocation.latitude.toStringAsFixed(6)}, '
                        '${widget.currentLocation.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category/Tag selection
              const Text(
                'Category (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTag == tag;
                  return ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTag = selected ? tag : null;
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.black87,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Comment input
              const Text(
                'Your Comment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Share what you see, experience, or want to remember...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  counterStyle: const TextStyle(fontSize: 11),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Pick from gallery',
                        icon: const Icon(Icons.photo, color: AppColors.accent),
                        onPressed: _isSubmitting ? null : _pickFromGallery,
                      ),
                      IconButton(
                        tooltip: 'Capture photo',
                        icon: const Icon(Icons.camera_alt, color: AppColors.accent),
                        onPressed: _isSubmitting ? null : _pickPhoto,
                      ),
                    ],
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),

              // Thumbnail preview (if any)
              if (_pickedImage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb && _webImage != null
                        ? Image.memory(
                            _webImage!,
                            height: 64,
                            width: 64,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_pickedImage!.path),
                            height: 64,
                            width: 64,
                            fit: BoxFit.cover,
                          ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _pickedImage = null;
                              _webImage = null;
                              });
                            },
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      label: const Text(
                        'Remove photo',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitComment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Add Comment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
