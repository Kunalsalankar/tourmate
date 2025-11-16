# TourMate V6 – Map Performance, Accuracy, and Admin Pagination Updates

This README documents the recent changes that improve map performance, route accuracy, and admin checkpoint list scalability. It also explains how to configure the Google Maps renderer and the Google Roads API for road-aligned polylines.

## Summary of What Changed
- Map visualization (TripMapScreen) with clustering, downsampling, and live location follow
- Road-aligned polylines (Snap to Roads) via Google Roads API
- Performance tuning for Google Maps Flutter on Android
- Location recording tuned for reduced churn and better validity
- Admin Checkpoints screen now paginated with infinite scroll
- Checkpoint sampling interval set to 10 seconds

---

## Configuration

### .env variables
Place a `.env` file at the project root with keys below. These are used at runtime by `flutter_dotenv`.

```
# Roads API / Google Maps Web Service key (HTTP). Use ONE of these.
GOOGLE_MAPS_API_KEY=YOUR_HTTP_KEY
# or
GOOGLE_API_KEY=YOUR_HTTP_KEY
# or
ROADS_API_KEY=YOUR_HTTP_KEY

# Android renderer configuration (optional; helps on some GPUs)
# latest | legacy
MAPS_ANDROID_RENDERER=legacy
# true | false (hybrid composition SurfaceProducer)
MAPS_ANDROID_VIEW_SURFACE=false
```

Notes:
- Use a Web Service (HTTP) key for Roads API (server/web), not an Android-app-restricted key.
- For security, restrict the HTTP key to the “Roads API” only.

### Dependencies
Run:
```
flutter pub get
```
Key packages impacted/added:
- google_maps_flutter
- google_maps_flutter_android
- google_maps_flutter_platform_interface
- geolocator
- flutter_dotenv

### Build/Run
Prefer Release for realistic performance:
```
flutter run --release
```

---

## Map Screen (TripMapScreen)
File: `lib/user/trip_map_screen.dart`

### Features
- Shows a user’s trip checkpoints on Google Maps
- Marker clustering with zoom-aware grid to reduce marker count
- Polyline downsampling by zoom for smooth panning/zooming
- Live follow mode (camera animates to latest point, throttled)
- Toggle: “Show full route” (default shows last 800 points for performance)
- Toggle: “High accuracy ON/OFF” (disables polyline downsampling when ON)
- Toggle: “Road align ON/OFF” (Snap to Roads, ON by default)
- Geodesic polylines for more natural paths
 - Start/End markers and dots:
   - Start of the route marked with a RED marker
   - End of the route marked with a GREEN marker
   - Intermediate checkpoints rendered as small dot circles

### Weather and Air Quality (NEW)
- Shows current Temperature and AQI chips
- Where it appears:
  - AppBar on Home screen (refresh on tap)
  - AppBar on Navigation screen (refresh on tap)
- Data sources:
  - Google Weather API: Current Conditions
  - Google Air Quality API: Current Conditions (Universal AQI)
- Configuration:
  - Enable both APIs for your Google Cloud project
  - Add one of these to `.env` (first non-empty used):
    - `WEATHER_API_KEY`
    - `GOOGLE_API_KEY`
    - `GOOGLE_MAPS_API_KEY`
    - `AIR_QUALITY_API_KEY`
  - Location permission required to fetch current coordinates
- Performance:
  - Fetched once on screen open; Tap chips to refresh on demand
  - 5s HTTP timeout and graceful fallback if request fails

### Road Align (Snap to Roads)
- Enabled by default
- When ON, the map overlays a thicker snapped polyline on top of a faint base polyline
- Chunked requests (≤100 points/request) with caching
- A small spinner shows while snapping; failures show a red banner (with error details)
- Uses any of `.env` keys: `GOOGLE_MAPS_API_KEY` or `GOOGLE_API_KEY` or `ROADS_API_KEY`

### Performance optimizations
- Disabled heavy gestures/layers: rotate/tilt/buildings/traffic/indoor
- `liteModeEnabled` automatically for very large paths (Android)
- `minMaxZoomPreference(3, 19)` to reduce tile work
- Compute bounds once per session or when toggling “Show full route”
- Marker workload reduced at low zoom: only latest marker visible
- Marker clustering via grid buckets keyed by zoom
- Polyline downsampling sized by zoom level
- Camera animation throttling to avoid jank

### Android renderer and platform view
File: `lib/main.dart`
- Enables Android view surface (hybrid composition) when configured
- Renderer initialization with fallback (latest → legacy) driven by `.env`
- Mitigates GPU/driver issues on some Mali devices

### Accuracy improvements for displayed data
- Strict coordinate filter: ignore points where either lat or lng is `0.0`
- Geodesic polylines
- Optional High Accuracy toggle to display the full path without downsampling

---

## Location Recording (NotificationCubit)
File: `lib/cubit/notification_cubit.dart`

### Changes
- Checkpoint sampling interval set to 10 seconds for higher fidelity
- Location stream tuned for lower churn: `LocationAccuracy.medium`, `distanceFilter: 30`
- Before writing each checkpoint, attempt a fresh high-accuracy fix with a short timeout.
- If no valid position is available, the checkpoint write is skipped (prevents `(0,0)`)

### Impact
- Higher map fidelity and smoother route visualization
- Slightly higher battery/network usage versus 30s; still uses medium-accuracy stream with 30m filter and on-demand fresh fix

---

## Admin Checkpoints Pagination
Files:
- `lib/cubit/admin_checkpoint_cubit.dart`
- `lib/admin/admin_checkpoints_screen.dart`

### What’s implemented
- Paginated fetch of checkpoints instead of a single full stream
- Infinite scroll: loading more pages when reaching the bottom
- Loading footer for visibility when fetching more
- Removed an unused `_onCheckpointsUpdated` method to clear lint

### Impact
- Substantially reduces memory and CPU usage on large datasets
- Smoother scrolling for admins

---

## Repository Additions
File: `lib/core/repositories/checkpoint_repository.dart`
- `getTripCheckpointsForUser(userId, tripId)`: stream checkpoints for a specific trip, client-side sorted by timestamp ascending
- Added paginated fetch helpers for admin usage

---

## UI Entrypoints
Files:
- `lib/presentation/screens/notification_screen.dart`: “View Map” button
- `lib/user/home_screen.dart`: “View Map” button in trip details

### Navigation
- Opens `TripMapScreen` for the selected trip

---

## Troubleshooting
- No snapped line and no red banner: likely road align is off or not enough points to see a difference; zoom in and enable “High accuracy ON”
- Red banner: check `.env` key; must be a Roads API web-service key (HTTP) and not Android-restricted
- Android GPU logs (e.g., Flogger spam, ImageReader warnings): expected on some devices with hybrid composition; switch via `.env` to `MAPS_ANDROID_RENDERER=legacy` and `MAPS_ANDROID_VIEW_SURFACE=false`
- Performance tips: keep “Show full route” OFF for very large trips; increase zoom level; ensure Release mode

---

## Future Enhancements (Optional)
- Use a dedicated clustering library for very large datasets
- Snap only the latest segment (last N minutes/points) to save quota and improve responsiveness
- Filter by horizontal accuracy (discard points when accuracy is poor)
- Persist snapped geometry per trip to avoid repeated API calls

---

## Changelog (Files Modified)
- `lib/user/trip_map_screen.dart` – Created and enhanced: clustering, sampling, downsampling, geodesic polylines, follow mode, Road Align toggle (default ON), High Accuracy toggle, performance options, Android lite mode, caching, error banner
- `lib/cubit/notification_cubit.dart` – Interval 30s, medium accuracy + 30m filter, fresh fix before write, skip invalid, local state updates
- `lib/cubit/admin_checkpoint_cubit.dart` – Pagination, load more, removed unused method
- `lib/admin/admin_checkpoints_screen.dart` – Infinite scroll integration and loading footer
- `lib/core/repositories/checkpoint_repository.dart` – Trip checkpoints stream and admin pagination helpers
- `lib/presentation/screens/notification_screen.dart` – “View Map” navigation, UI text update
- `lib/user/home_screen.dart` – “View Map” in trip details dialog (past trips)
- `lib/main.dart` – Android renderer config (latest/legacy) + Android view surface, notification setup
- `pubspec.yaml` – Added maps/android platform packages and ensured required deps

---

## License
Internal project documentation. Update as needed.
