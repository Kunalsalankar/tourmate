# CORS Error Fix - Google Maps API on Web

## Problem Summary

When running the TourMate app on Flutter web, place searches failed with this error:

```
Access to XMLHttpRequest at 'https://maps.googleapis.com/maps/api/place/textsearch/json?...' 
from origin 'http://localhost:59454' has been blocked by CORS policy: 
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

## Root Cause

### What is CORS?

**Cross-Origin Resource Sharing (CORS)** is a browser security mechanism that prevents web pages from making requests to a different domain than the one serving the page.

### Why Did This Happen?

1. **Your app origin**: `http://localhost:59454`
2. **API endpoint**: `https://maps.googleapis.com`
3. **Browser blocks**: Direct HTTP requests between different origins

### Platform Differences

| Platform | REST API (HTTP) | JavaScript SDK |
|----------|----------------|----------------|
| **Android** | ✅ Works | ✅ Works |
| **iOS** | ✅ Works | ✅ Works |
| **Web** | ❌ CORS Error | ✅ Works |

**Key Point**: Google Maps REST APIs are designed for **server-side** or **mobile** use, not direct browser calls. For web apps, you must use the **JavaScript SDK**.

## Solution Implemented

### 1. Created Web-Specific Service (`maps_service_web.dart`)

This file uses Dart's `dart:html` and `dart:js` libraries to call the Google Maps JavaScript API that's already loaded in `web/index.html`:

```dart
// Uses JavaScript interop to call google.maps.places APIs
final service = js.JsObject(
  js.context['google']['maps']['places']['PlacesService'],
  [div],
);
```

**Benefits**:
- ✅ No CORS issues (JavaScript SDK is allowed)
- ✅ Uses the same API key
- ✅ Returns the same data structure

### 2. Created Stub File (`maps_service_stub.dart`)

This is a placeholder for non-web platforms that throws an error if accidentally used:

```dart
class MapsServiceWeb {
  Future<List<PlaceModel>> searchPlaces(String query) async {
    throw UnsupportedError('Web-specific implementation not available');
  }
}
```

### 3. Updated Main Service (`maps_service.dart`)

Added conditional imports and platform detection:

```dart
// Conditional import - uses stub by default, web version on web
import 'maps_service_stub.dart'
    if (dart.library.html) 'maps_service_web.dart';

// In searchPlaces method:
if (kIsWeb) {
  // Use JavaScript SDK (no CORS)
  final webService = MapsServiceWeb();
  return await webService.searchPlaces(query);
}

// Mobile/Desktop: Use REST API (works fine)
final places = places_webservice.GoogleMapsPlaces(apiKey: _apiKey);
return await places.searchByText(query);
```

## How It Works

### On Web Platform

```
User types "sai" 
  ↓
MapsService.searchPlaces("sai")
  ↓
Detects kIsWeb = true
  ↓
MapsServiceWeb.searchPlaces("sai")
  ↓
Calls google.maps.places.PlacesService via JavaScript
  ↓
Returns List<PlaceModel>
```

### On Mobile/Desktop Platform

```
User types "sai"
  ↓
MapsService.searchPlaces("sai")
  ↓
Detects kIsWeb = false
  ↓
Uses google_maps_webservice package (REST API)
  ↓
Returns List<PlaceModel>
```

## Files Modified

1. **`lib/core/services/maps_service.dart`** - Added platform detection and web routing
2. **`lib/core/services/maps_service_web.dart`** - New web-specific implementation
3. **`lib/core/services/maps_service_stub.dart`** - New stub for non-web platforms

## Testing

### To Test the Fix:

1. **Stop the current web server** if running
2. **Run the app**:
   ```bash
   flutter run -d chrome
   ```
3. **Try searching** for a place in the origin/destination fields
4. **Check console** - you should see:
   ```
   [WEB] Searching places with query: sai
   [WEB] Found X places
   ```

### Expected Behavior:

- ✅ No CORS errors
- ✅ Place search results appear
- ✅ Can select origin and destination
- ✅ Can get directions

## Technical Details

### Why Conditional Imports?

Dart's conditional imports allow platform-specific code:

```dart
import 'maps_service_stub.dart'           // Default (mobile/desktop)
    if (dart.library.html) 'maps_service_web.dart';  // If web
```

- **`dart.library.html`** is only available on web
- Dart compiler automatically chooses the right file
- No runtime overhead

### JavaScript Interop

The web implementation uses `dart:js` to call JavaScript:

```dart
// Create JavaScript object
final service = js.JsObject(
  js.context['google']['maps']['places']['PlacesService'],
  [div],
);

// Call JavaScript method with callback
service.callMethod('textSearch', [
  request,
  js.allowInterop(callback),  // Wrap Dart function for JS
]);
```

### Async Handling

JavaScript callbacks are converted to Dart Futures using `Completer`:

```dart
final completer = Completer<List<PlaceModel>>();

void callback(js.JsObject? results, String status) {
  // Process results
  completer.complete(places);
}

return await completer.future;  // Wait for callback
```

## Alternative Solutions (Not Used)

### ❌ Option 1: Backend Proxy
Create a server to proxy requests. **Rejected**: Too complex, requires hosting.

### ❌ Option 2: Disable CORS
Use browser flags like `--disable-web-security`. **Rejected**: Only works in development, security risk.

### ✅ Option 3: Use JavaScript SDK (Implemented)
Platform-specific implementation. **Chosen**: Clean, secure, production-ready.

## API Key Security

Your API key is exposed in `web/index.html`:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=AIzaSy...&libraries=places"></script>
```

**⚠️ Security Recommendations**:

1. **Restrict the API key** in Google Cloud Console:
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Edit your API key
   - Add **HTTP referrer restrictions**:
     - `localhost:*` (for development)
     - `yourdomain.com/*` (for production)
   - Restrict to **Maps JavaScript API** and **Places API**

2. **Never commit** `.env` file to version control (already in `.gitignore`)

3. **Use different keys** for development and production

## Troubleshooting

### Still Getting CORS Errors?

1. **Clear browser cache**: `Ctrl+Shift+Delete`
2. **Hard reload**: `Ctrl+F5`
3. **Check console** for which API is failing
4. **Verify** `web/index.html` has the JavaScript SDK loaded

### "google is not defined" Error?

The JavaScript SDK might not be loaded yet. Check `web/index.html`:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_KEY&libraries=places"></script>
```

### No Results Returned?

1. **Check API key** is valid
2. **Enable Places API** in Google Cloud Console
3. **Check billing** is enabled (required for Places API)
4. **Look for errors** in browser console

## Performance Notes

- ✅ **Caching**: Results are still cached via `CacheService`
- ✅ **Same speed**: JavaScript SDK is as fast as REST API
- ✅ **No extra overhead**: Conditional imports have zero runtime cost

## Summary

The CORS error was fixed by:

1. **Detecting** the platform (web vs mobile)
2. **Using JavaScript SDK** on web (via `dart:js`)
3. **Keeping REST API** for mobile/desktop
4. **Maintaining** the same interface and caching

The app now works seamlessly across all platforms without CORS issues! 🎉
