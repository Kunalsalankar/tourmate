import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../cubit/location_comment_cubit.dart';
import '../core/models/location_comment_model.dart';
import '../core/colors.dart';
import 'add_location_comment_screen.dart';

class LocationCommentsScreen extends StatefulWidget {
  const LocationCommentsScreen({super.key});

  @override
  State<LocationCommentsScreen> createState() => _LocationCommentsScreenState();
}

class _LocationCommentsScreenState extends State<LocationCommentsScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _showMap = true;

  @override
  void initState() {
    super.initState();
    context.read<LocationCommentCubit>().initialize();
  }

  void _updateMarkers(List<LocationCommentModel> comments) {
    _markers.clear();
    for (final comment in comments) {
      _markers.add(
        Marker(
          markerId: MarkerId(comment.id ?? comment.uid),
          position: LatLng(comment.lat, comment.lng),
          infoWindow: InfoWindow(
            title: comment.userName,
            snippet: comment.comment,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Comments'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<LocationCommentCubit>().refresh();
            },
          ),
        ],
      ),
      body: BlocConsumer<LocationCommentCubit, LocationCommentState>(
        listener: (context, state) {
          if (state is LocationCommentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is LocationCommentAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Comment added successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is LocationCommentLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (state is LocationCommentError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (state is LocationCommentLoaded) {
            _updateMarkers(state.allComments);
            
            return _showMap
                ? _buildMapView(state)
                : _buildListView(state);
          }

          return const Center(child: Text('Initializing...'));
        },
      ),
      
    );
  }

  Widget _buildMapView(LocationCommentLoaded state) {
    final position = state.currentPosition;
    
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: position != null
            ? LatLng(position.latitude, position.longitude)
            : const LatLng(20.5937, 78.9629), // India center
        zoom: 14,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onMapCreated: (controller) {
        _mapController = controller;
        if (position != null) {
          controller.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      },
      circles: position != null
          ? {
              Circle(
                circleId: const CircleId('proximity'),
                center: LatLng(position.latitude, position.longitude),
                radius: 200, // 200 meters
                fillColor: AppColors.primary.withOpacity(0.2),
                strokeColor: AppColors.primary,
                strokeWidth: 2,
              ),
            }
          : {},
    );
  }

  Widget _buildListView(LocationCommentLoaded state) {
    final nearby = state.nearbyComments;
    final all = state.allComments;

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<LocationCommentCubit>().refresh();
      },
      child: CustomScrollView(
        slivers: [
          if (nearby.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.primaryLight.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Nearby Comments (${nearby.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCommentCard(nearby[index], true),
                childCount: nearby.length,
              ),
            ),
            const SliverToBoxAdapter(child: Divider(thickness: 2)),
          ],
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Text(
                'All Comments (${all.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCommentCard(all[index], false),
              childCount: all.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(LocationCommentModel comment, bool isNearby) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isNearby ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNearby
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userName.isEmpty ? 'Anonymous' : comment.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(comment.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isNearby)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NEARBY',
                      style: TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              comment.comment,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppColors.iconSecondary),
                const SizedBox(width: 4),
                Text(
                  '${comment.lat.toStringAsFixed(4)}, ${comment.lng.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (comment.tags != null && comment.tags!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: comment.tags!
                    .map(
                      (tag) => Chip(
                        label: Text(
                          tag,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: AppColors.secondaryLight.withOpacity(0.3),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}