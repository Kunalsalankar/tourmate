# How to Run and Test Automatic Trip Detection

## ✅ What's Been Done

1. **Unit Tests**: ✅ All 13 tests passed
2. **Code Implementation**: ✅ Complete
3. **Documentation**: ✅ Comprehensive
4. **Demo Mode**: ✅ Created for UI testing

---

## 🚀 Option 1: Run Demo Mode (Windows/Any Platform)

**Purpose**: Test the UI without GPS sensors

### Command:
```bash
flutter run -d windows -t lib/demo_main.dart
```

### What You Can Test:
- ✅ UI layout and design
- ✅ Start/Stop detection button
- ✅ Simulate trip functionality
- ✅ Trip confirmation screen
- ✅ Map visualization
- ✅ Form inputs (purpose, mode, companions, cost)

### Steps:
1. App opens with demo home screen
2. Click "Open Demo"
3. Click "Start Detection"
4. Click "Simulate Trip"
5. Wait 2 seconds - trip will be "detected"
6. Click "Confirm" on pending trip
7. Fill in trip details
8. Click "Confirm Trip"

**Note**: This is UI-only testing. GPS detection logic cannot be tested without real sensors.

---

## 🚀 Option 2: Run on Android Device (Real Testing)

**Purpose**: Test actual GPS-based trip detection

### Prerequisites:
1. Android phone with USB debugging enabled
2. USB cable
3. Location services enabled on phone

### Command:
```bash
# Check if device is connected
flutter devices

# Run on Android device
flutter run -d <device-id>
```

### What You Can Test:
- ✅ Real GPS tracking
- ✅ Trip start detection (3 min movement)
- ✅ Trip end detection (5 min stationary)
- ✅ Distance calculation
- ✅ Speed tracking
- ✅ Mode inference
- ✅ Background tracking
- ✅ Battery usage

### Steps:
1. Connect Android phone via USB
2. Run: `flutter run`
3. Navigate to Trip Detection screen
4. Tap "Start Detection"
5. Grant location permissions
6. **Actually walk/drive** for at least 5 minutes and 300 meters
7. Stop for 5 minutes
8. Check if trip is detected

**Important**: You need to physically move for realistic testing!

---

## 🧪 Run Unit Tests

### Command:
```bash
flutter test test/trip_detection_test.dart
```

### Expected Output:
```
00:14 +13: All tests passed!
```

### What's Tested:
- ✅ AutoTripModel creation and methods
- ✅ LocationPoint serialization
- ✅ Trip statistics calculation
- ✅ Configuration values
- ✅ Data conversion (to/from Map)

---

## 📱 Current Status

### ✅ Working on Windows (Demo Mode)
- UI testing
- Form validation
- Navigation flow
- Visual design

### ⏳ Requires Android/iOS Device
- GPS tracking
- Trip detection algorithms
- Background location
- Real-world testing

---

## 🎯 Quick Start Guide

### For UI Testing (Now):
```bash
# Terminal 1: Run demo
flutter run -d windows -t lib/demo_main.dart

# Terminal 2: Watch logs
flutter logs
```

### For Real Testing (Later):
```bash
# 1. Connect Android phone
# 2. Enable USB debugging
# 3. Run:
flutter run

# 4. Navigate to Trip Detection in app
# 5. Start detection
# 6. Go for a walk/drive
```

---

## 📊 Test Results

### Unit Tests: ✅ PASSED
```
✓ 13/13 tests passed
✓ No errors
✓ All models working correctly
```

### Demo Mode: ✅ RUNNING
```
✓ App launched on Windows
✓ UI displays correctly
✓ Demo trip simulation works
✓ Confirmation screen accessible
```

### Real Device Testing: ⏳ PENDING
```
⏳ Requires Android/iOS device
⏳ Requires physical movement
⏳ See TESTING_GUIDE.md for details
```

---

## 🔍 What to Look For

### In Demo Mode:
1. **Detection Screen**:
   - Start/Stop button works
   - Status updates correctly
   - Demo notice visible

2. **Simulate Trip**:
   - Trip appears in pending list
   - Distance, duration, speed shown
   - Mode detected correctly

3. **Confirmation Screen**:
   - Map displays (may need API key)
   - All form fields editable
   - Purpose chips work
   - Mode dropdown works
   - Confirm/Reject buttons work

### On Real Device:
1. **Permission Flow**:
   - Location permission requested
   - Background location requested (Android 10+)
   - Graceful handling of denials

2. **Trip Detection**:
   - Starts after 3 min movement
   - Tracks distance accurately
   - Calculates speed correctly
   - Ends after 5 min stationary

3. **Background Tracking**:
   - Works when app in background
   - Foreground service notification (Android)
   - No crashes

---

## 🐛 Troubleshooting

### Demo Mode Issues

**Issue**: App won't start
```bash
# Solution:
flutter clean
flutter pub get
flutter run -d windows -t lib/demo_main.dart
```

**Issue**: Map not showing
```bash
# Solution: Map requires API key
# For demo, map may not load - this is OK
# Focus on testing other UI elements
```

### Real Device Issues

**Issue**: Device not detected
```bash
# Check USB debugging enabled
adb devices

# Restart adb
adb kill-server
adb start-server
```

**Issue**: Permission denied
```bash
# Manually grant in phone settings:
# Settings → Apps → TourMate → Permissions → Location → Allow all the time
```

---

## 📁 Important Files

### Implementation:
- `lib/core/models/auto_trip_model.dart` - Data models
- `lib/core/services/trip_detection_service.dart` - Detection logic
- `lib/core/repositories/auto_trip_repository.dart` - Database
- `lib/cubit/trip_detection_cubit.dart` - State management
- `lib/user/trip_detection_screen.dart` - Main UI
- `lib/user/trip_confirmation_screen.dart` - Confirmation UI

### Testing:
- `test/trip_detection_test.dart` - Unit tests
- `lib/demo_main.dart` - Demo app entry point
- `lib/user/trip_detection_demo.dart` - Demo screen

### Documentation:
- `AUTOMATIC_TRIP_DETECTION.md` - Complete docs
- `INTEGRATION_GUIDE.md` - Integration steps
- `TESTING_GUIDE.md` - Testing procedures
- `QUICK_REFERENCE.md` - Quick reference
- `RUN_INSTRUCTIONS.md` - This file

---

## 🎉 Summary

### ✅ Completed:
- [x] Core implementation (7 files)
- [x] Unit tests (13 tests, all passing)
- [x] Demo mode for UI testing
- [x] Comprehensive documentation
- [x] Android permissions configured

### ⏳ Next Steps:
1. **Test demo mode** on Windows (running now)
2. **Review UI** and make any adjustments
3. **Connect Android device** for real testing
4. **Test trip detection** with actual movement
5. **Integrate** into main app navigation
6. **Deploy** to production

---

## 📞 Commands Reference

```bash
# Run demo (Windows/Mac/Linux)
flutter run -d windows -t lib/demo_main.dart

# Run on Android
flutter run -d android

# Run tests
flutter test test/trip_detection_test.dart

# Check devices
flutter devices

# View logs
flutter logs

# Clean and rebuild
flutter clean && flutter pub get && flutter run
```

---

## 🎯 Success Criteria

### Demo Mode: ✅
- [x] App launches
- [x] UI displays correctly
- [x] Simulate trip works
- [x] Confirmation screen accessible

### Real Device: ⏳ Pending
- [ ] Trip detection works
- [ ] Distance accurate (±10%)
- [ ] Mode detection reasonable
- [ ] Background tracking works
- [ ] Battery usage acceptable

---

**Status**: Demo Mode ✅ Running | Real Device Testing ⏳ Pending  
**Last Updated**: 2025-10-08  
**Version**: 1.0.0
