import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../core/colors.dart';
import '../core/models/checkpoint_model.dart';
import '../core/repositories/checkpoint_repository.dart';

class TripMapScreen extends StatefulWidget {
  final String tripId;
  final String? tripTitle;

  const TripMapScreen({super.key, required this.tripId, this.tripTitle});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final _repo = CheckpointRepository();
  final Completer<GoogleMapController> _mapController = Completer();
  double _zoom = 14;
  bool _followLatest = true;
  StreamSubscription<Position>? _positionSub;
  // Throttling
  String? _lastFollowedCheckpointId;
  DateTime _lastCameraUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _didInitialFit = false;
  bool _showAll = false;
  bool _highAccuracy = false;
  bool _roadAlign = true;
  bool _snapping = false;
  List<LatLng>? _cachedSnappedPolyline;
  String? _cachedSnapSig;
  static const int _snapSegmentMaxPoints = 200; // limit to recent segment for responsiveness
  DateTime _nextSnapAllowedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _startLocationStream();
  }
  
  List<LatLng> _downsamplePolyline(List<LatLng> pts, int maxPoints) {
    if (pts.length <= maxPoints) return pts;
    final step = (pts.length / maxPoints).ceil();
    final result = <LatLng>[];
    for (int i = 0; i < pts.length; i += step) {
      result.add(pts[i]);
    }
    if (result.last != pts.last) result.add(pts.last);
    return result;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Trip Map'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
        ),
        body: const Center(
          child: Text('You must be signed in to view the map.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tripTitle?.isNotEmpty == true ? widget.tripTitle! : 'Trip Map'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: StreamBuilder<List<CheckpointModel>>(
        stream: _repo.getTripCheckpointsForUser(user.uid, widget.tripId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading checkpoints: ${snapshot.error}'));
          }

          final checkpoints = snapshot.data ?? [];
          if (checkpoints.isEmpty) {
            return const Center(child: Text('No checkpoints yet for this trip.'));
          }

          // Limit to last 800 checkpoints unless user opts in to full route
          final visibleCheckpoints = (!_showAll && checkpoints.length > 800)
              ? checkpoints.sublist(checkpoints.length - 800)
              : checkpoints;

          final points = visibleCheckpoints
              .map((c) => LatLng(c.latitude, c.longitude))
              .where((p) => p.latitude != 0.0 && p.longitude != 0.0)
              .toList();

          if (points.isEmpty) {
            return const Center(child: Text('Checkpoints have no valid coordinates yet.'));
          }

          final lastIndex = points.length - 1;
          final displayIdxs = _selectDisplayIndexes(points.length, _zoom);
          if (!displayIdxs.contains(lastIndex)) displayIdxs.add(lastIndex);
          displayIdxs.sort();
          final displayPoints = [for (final i in displayIdxs) points[i]];

          // Start/End markers and intermediate dots
          final Set<Marker> markers = {};
          final Set<Circle> circles = {};
          final startPoint = points.first;
          final endPoint = points.last;
          // Start marker (RED)
          markers.add(Marker(
            markerId: const MarkerId('start'),
            position: startPoint,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ));
          // End marker (GREEN)
          if (points.length > 1) {
            markers.add(Marker(
              markerId: const MarkerId('end'),
              position: endPoint,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ));
          }
          // Intermediate checkpoints as small dots (downsampled by displayPoints)
          for (int i = 0; i < displayPoints.length; i++) {
            final p = displayPoints[i];
            if ((p.latitude == startPoint.latitude && p.longitude == startPoint.longitude) ||
                (p.latitude == endPoint.latitude && p.longitude == endPoint.longitude)) {
              continue;
            }
            circles.add(Circle(
              circleId: CircleId('dot_$i'),
              center: p,
              radius: 6, // meters
              strokeWidth: 0,
              fillColor: AppColors.primary.withOpacity(0.6),
            ));
          }

          final maxPts = _polylineMaxPointsForZoom(_zoom);
          final basePolylinePoints = _highAccuracy ? points : _downsamplePolyline(points, maxPts);

          // If road-align is enabled, ensure we have a snapped polyline cached for the recent segment
          if (_roadAlign) {
            final recentSegment = _selectSnapSegment(points, _snapSegmentMaxPoints);
            final snapBase = _highAccuracy ? recentSegment : _downsamplePolyline(recentSegment, 90); // keep under 100 when not high accuracy
            final desiredSig = _pointsSig(snapBase);
            final now = DateTime.now();
            final onCooldown = now.isBefore(_nextSnapAllowedAt);
            if ((
                  _cachedSnapSig != desiredSig || _cachedSnappedPolyline == null
                ) && !onCooldown) {
              // Schedule async fetch after this frame to avoid setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _ensureSnappedPolyline(snapBase);
              });
            }
          }

          // Build polylines: when road-align is available, overlay snapped segment on top of base
          final Set<Polyline> polylines;
          if (_roadAlign && _cachedSnappedPolyline != null) {
            polylines = {
              Polyline(
                polylineId: const PolylineId('route_base'),
                color: Colors.black.withOpacity(0.25),
                width: 2,
                geodesic: true,
                points: basePolylinePoints,
              ),
              Polyline(
                polylineId: const PolylineId('route_snapped'),
                color: AppColors.primary,
                width: 4,
                geodesic: true,
                points: _cachedSnappedPolyline!,
              ),
            };
          } else {
            polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                color: AppColors.primary,
                width: 3,
                geodesic: true,
                points: basePolylinePoints,
              ),
            };
          }

          final bounds = !_didInitialFit ? _computeBounds(points) : null;
          if (_followLatest) {
            final newLastId = visibleCheckpoints.last.id;
            final now = DateTime.now();
            if (newLastId != _lastFollowedCheckpointId &&
                now.difference(_lastCameraUpdate) > const Duration(milliseconds: 600)) {
              _lastFollowedCheckpointId = newLastId;
              _scheduleCameraToPoint(points.last);
            }
          }

          return Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (checkpoints.length > 800)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showAll = !_showAll;
                            _didInitialFit = false; // allow one-time bounds fit again
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(
                          _showAll ? 'Showing full route' : 'Show full route',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _highAccuracy = !_highAccuracy;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _highAccuracy ? AppColors.primary : Colors.black.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        _highAccuracy ? 'High accuracy ON' : 'High accuracy OFF',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _roadAlign = !_roadAlign;
                          // Invalidate cached snap if turning off won't matter; turning on will refetch next frame
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _roadAlign ? AppColors.primary : Colors.black.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        _roadAlign ? 'Road align ON' : 'Road align OFF',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (_snapping)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              GoogleMap(
                initialCameraPosition: CameraPosition(target: points.last, zoom: 14),
                onMapCreated: (controller) async {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                  if (bounds != null && !_didInitialFit) {
                    await Future.delayed(const Duration(milliseconds: 300));
                    try {
                      await controller.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 48),
                      );
                      _didInitialFit = true;
                    } catch (_) {}
                  }
                },
                onCameraMove: (position) {
                  _zoom = position.zoom;
                },
                onCameraIdle: () {},
                onCameraMoveStarted: () {
                  if (_followLatest) {
                    setState(() => _followLatest = false);
                  }
                },
                markers: markers,
                circles: circles,
                polylines: polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                compassEnabled: true,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                buildingsEnabled: false,
                trafficEnabled: false,
                indoorViewEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                liteModeEnabled: (!_showAll && points.length > 5000),
                minMaxZoomPreference: const MinMaxZoomPreference(3, 19),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _followLatest = !_followLatest);
                    if (_followLatest) {
                      if (!_didInitialFit && bounds != null) {
                        await _scheduleCameraFit(bounds, points.last);
                        _didInitialFit = true;
                      } else {
                        _scheduleCameraToPoint(points.last);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _followLatest ? AppColors.primary : Colors.grey[700],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: Icon(
                    _followLatest ? Icons.my_location : Icons.location_disabled,
                    color: AppColors.textOnPrimary,
                    size: 18,
                  ),
                  label: Text(
                    _followLatest ? 'Following' : 'Follow',
                    style: const TextStyle(color: AppColors.textOnPrimary),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  LatLngBounds? _computeBounds(List<LatLng> points) {
    if (points.isEmpty) return null;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  int _polylineMaxPointsForZoom(double z) {
    if (z < 8) return 400;
    if (z < 10) return 600;
    if (z < 12) return 800;
    if (z < 14) return 1000;
    return 1200;
  }

  

  Future<void> _ensureSnappedPolyline(List<LatLng> snapBase) async {
    if (_snapping || !mounted) return;
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'] ?? dotenv.env['ROADS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      // Avoid retry spam until user fixes key
      setState(() {
        _cachedSnapSig = _pointsSig(snapBase);
        _nextSnapAllowedAt = DateTime.now().add(const Duration(minutes: 5));
      });
      return;
    }
    setState(() => _snapping = true);
    try {
      // Split into chunks of <= 100 points as per Snap to Roads limit
      const maxPer = 100;
      final snappedAll = <LatLng>[];
      for (int i = 0; i < snapBase.length; i += maxPer) {
        final seg = snapBase.sublist(i, i + maxPer > snapBase.length ? snapBase.length : i + maxPer);
        final segSnapped = await _snapToRoads(seg, apiKey);
        if (segSnapped.isEmpty) continue;
        if (snappedAll.isNotEmpty && _latLngEquals(snappedAll.last, segSnapped.first)) {
          segSnapped.removeAt(0);
        }
        snappedAll.addAll(segSnapped);
      }
      if (!mounted) return;
      setState(() {
        _cachedSnappedPolyline = snappedAll;
        _cachedSnapSig = _pointsSig(snapBase);
        _nextSnapAllowedAt = DateTime.now().add(const Duration(seconds: 30));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cachedSnapSig = _pointsSig(snapBase);
        _nextSnapAllowedAt = DateTime.now().add(const Duration(minutes: 2));
      });
    } finally {
      if (mounted) setState(() => _snapping = false);
    }
  }

  Future<List<LatLng>> _snapToRoads(List<LatLng> pts, String apiKey) async {
    if (pts.isEmpty) return [];
    final path = pts.map((p) => '${p.latitude},${p.longitude}').join('|');
    final uri = Uri.parse('https://roads.googleapis.com/v1/snapToRoads?interpolate=true&key=$apiKey&path=$path');
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) {
      final body = resp.body;
      final snippet = body.length > 200 ? body.substring(0, 200) + '…' : body;
      throw Exception('HTTP ${resp.statusCode}: $snippet');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final list = (data['snappedPoints'] as List?) ?? const [];
    return list.map((e) {
      final loc = (e as Map<String, dynamic>)['location'] as Map<String, dynamic>;
      return LatLng((loc['latitude'] as num).toDouble(), (loc['longitude'] as num).toDouble());
    }).toList();
  }

  bool _latLngEquals(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 1e-6 && (a.longitude - b.longitude).abs() < 1e-6;
  }

  List<LatLng> _selectSnapSegment(List<LatLng> pts, int maxCount) {
    if (pts.length <= maxCount) return List<LatLng>.from(pts);
    return pts.sublist(pts.length - maxCount);
  }

  Future<void> _startLocationStream() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 30,
        ),
      ).listen((pos) async {
        if (!mounted) return;
        if (_followLatest) {
          final now = DateTime.now();
          if (now.difference(_lastCameraUpdate) > const Duration(milliseconds: 800)) {
            final controller = await _mapController.future;
            try {
              await controller.animateCamera(
                CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
              );
              _lastCameraUpdate = now;
            } catch (_) {}
          }
        }
      });
    } catch (_) {
      // ignore location errors; map will still work via checkpoints
    }
  }

  String _pointsSig(List<LatLng> pts) {
    if (pts.isEmpty) return '0';
    final first = pts.first;
    final last = pts.last;
    return '${pts.length}_${first.latitude.toStringAsFixed(4)}_${first.longitude.toStringAsFixed(4)}_${last.latitude.toStringAsFixed(4)}_${last.longitude.toStringAsFixed(4)}';
  }

  // Select a subset of indices to render as small dots for performance
  List<int> _selectDisplayIndexes(int count, double z) {
    if (count <= 1500) {
      return List<int>.generate(count, (i) => i);
    }
    int stride;
    if (z < 8) {
      stride = 50;
    } else if (z < 10) {
      stride = 25;
    } else if (z < 12) {
      stride = 10;
    } else if (z < 14) {
      stride = 5;
    } else {
      stride = 2;
    }
    final idxs = <int>[];
    for (int i = 0; i < count; i += stride) {
      idxs.add(i);
    }
    if (!idxs.contains(count - 1)) idxs.add(count - 1);
    return idxs;
  }
  

  Future<void> _scheduleCameraFit(LatLngBounds? bounds, LatLng lastPoint) async {
    final controller = await _mapController.future;
    final now = DateTime.now();
    if (now.difference(_lastCameraUpdate) < const Duration(milliseconds: 500)) return;
    try {
      if (bounds != null) {
        await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
      } else {
        await controller.animateCamera(CameraUpdate.newLatLng(lastPoint));
      }
      _lastCameraUpdate = now;
    } catch (_) {}
  }

  void _scheduleCameraToPoint(LatLng point) async {
    final controller = await _mapController.future;
    final now = DateTime.now();
    if (now.difference(_lastCameraUpdate) < const Duration(milliseconds: 500)) return;
    try {
      await controller.animateCamera(CameraUpdate.newLatLng(point));
      _lastCameraUpdate = now;
    } catch (_) {}
  }
}
