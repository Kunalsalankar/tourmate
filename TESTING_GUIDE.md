# Automatic Trip Detection - Testing Guide

## ✅ Unit Tests - PASSED

All unit tests have been executed successfully:

```
✓ Create AutoTripModel with valid data
✓ Calculate trip duration correctly
✓ Convert to/from Map correctly
✓ Speed thresholds are correct
✓ Distance thresholds are correct
✓ Time thresholds are correct
✓ Mode detection speed ranges are correct
✓ Create LocationPoint with valid data
✓ Convert LocationPoint to/from Map
✓ All status values exist
✓ Calculate distance in kilometers
✓ Calculate speed in km/h
✓ CopyWith creates new instance with updated values

Total: 13 tests passed ✅
```

---

## 📱 Real Device Testing Required

**⚠️ IMPORTANT**: Automatic trip detection requires GPS sensors and cannot be fully tested on:
- Windows Desktop
- Web browsers
- Emulators without GPS simulation

**You MUST test on a real Android or iOS device.**

---

## 🚀 How to Run on Real Device

### Option 1: Android Device (Recommended)

1. **Enable Developer Mode on your Android phone:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - Go back to Settings → Developer Options
   - Enable "USB Debugging"

2. **Connect your phone via USB**

3. **Check if device is detected:**
   ```bash
   flutter devices
   ```
   You should see your Android device listed.

4. **Run the app:**
   ```bash
   flutter run -d <device-id>
   ```
   Or simply:
   ```bash
   flutter run
   ```
   (Flutter will prompt you to select a device)

5. **Grant permissions when prompted:**
   - Allow location access
   - Allow background location (Android 10+)

### Option 2: iOS Device

1. **Connect your iPhone via USB**

2. **Trust your Mac on the iPhone**

3. **Run:**
   ```bash
   flutter run -d <device-id>
   ```

4. **Grant location permissions when prompted**

---

## 🧪 Testing Scenarios

### Test 1: Basic Trip Detection (Walking)

**Objective**: Verify trip start and end detection

**Steps:**
1. Open the app
2. Navigate to "Trip Detection" screen
3. Tap "Start Detection"
4. Grant location permissions
5. **Walk continuously for 5 minutes** (at least 300 meters)
6. **Stop and wait for 5 minutes**
7. Check if trip is detected

**Expected Result:**
- ✅ Trip starts after ~3 minutes of walking
- ✅ Live tracking shows distance and duration
- ✅ Trip ends after ~5 minutes of being stationary
- ✅ Notification appears: "Trip Detected!"
- ✅ Trip appears in pending list
- ✅ Detected mode: "Walking"

**Pass Criteria:**
- [ ] Trip started automatically
- [ ] Distance tracked correctly (±10%)
- [ ] Duration calculated correctly
- [ ] Trip ended automatically
- [ ] Mode detected as "Walking"

---

### Test 2: Short Trip Rejection

**Objective**: Verify trips < 300m are discarded

**Steps:**
1. Start detection
2. Walk for 3 minutes but only ~100 meters
3. Stop for 5 minutes

**Expected Result:**
- ✅ Trip starts
- ✅ Trip ends
- ✅ Trip is **discarded** (not saved)
- ✅ No notification shown
- ✅ No pending trip

**Pass Criteria:**
- [ ] Short trip not saved
- [ ] No notification

---

### Test 3: Car Trip Detection

**Objective**: Verify mode detection for car travel

**Steps:**
1. Start detection
2. Drive a car for at least 5 km
3. Stop for 5 minutes

**Expected Result:**
- ✅ Trip detected
- ✅ Distance: ~5 km
- ✅ Detected mode: "Car"
- ✅ Average speed: 30-60 km/h

**Pass Criteria:**
- [ ] Trip detected
- [ ] Mode: "Car" or "Motorcycle"
- [ ] Speed reasonable

---

### Test 4: Bus Trip Detection

**Objective**: Verify bus detection with stops

**Steps:**
1. Start detection
2. Take a bus (with multiple stops)
3. Travel at least 3 km
4. Stop for 5 minutes after getting off

**Expected Result:**
- ✅ Trip detected
- ✅ Detected mode: "Bus" (due to speed variance)
- ✅ Route includes all stops

**Pass Criteria:**
- [ ] Trip detected
- [ ] Mode: "Bus" or "Car"
- [ ] Multiple route points

---

### Test 5: Trip Confirmation

**Objective**: Verify confirmation workflow

**Steps:**
1. Complete a trip (any mode)
2. Tap notification or open pending trips
3. Review trip details
4. Select purpose: "Work"
5. Confirm mode: "Bus"
6. Add companions: "John, Jane"
7. Add cost: "50"
8. Add notes: "Morning commute"
9. Tap "Confirm Trip"

**Expected Result:**
- ✅ Confirmation screen shows:
  - Map with route
  - Distance, duration, speed
  - Detected mode
- ✅ All form fields work
- ✅ Trip saved with status: "confirmed"
- ✅ Trip appears in confirmed trips list

**Pass Criteria:**
- [ ] Map displays correctly
- [ ] All fields editable
- [ ] Trip saved successfully
- [ ] Data persisted in Firestore

---

### Test 6: Trip Rejection

**Objective**: Verify rejection workflow

**Steps:**
1. Complete a trip
2. Open confirmation screen
3. Tap "Reject"
4. Confirm rejection

**Expected Result:**
- ✅ Trip marked as "rejected"
- ✅ Trip removed from pending list
- ✅ Trip not shown in confirmed trips

**Pass Criteria:**
- [ ] Trip rejected
- [ ] Not in pending list

---

### Test 7: Background Tracking

**Objective**: Verify detection works in background

**Steps:**
1. Start detection
2. Press Home button (app goes to background)
3. Walk for 5 minutes
4. Open app again

**Expected Result:**
- ✅ Trip tracked in background
- ✅ Foreground service notification visible (Android)
- ✅ Trip data recorded

**Pass Criteria:**
- [ ] Background tracking works
- [ ] No data loss

---

### Test 8: Multiple Trips

**Objective**: Verify multiple trips in sequence

**Steps:**
1. Start detection
2. Complete trip 1 (walk 500m)
3. Confirm trip 1
4. Wait 10 minutes
5. Complete trip 2 (walk 500m)
6. Confirm trip 2

**Expected Result:**
- ✅ Both trips detected separately
- ✅ Both trips in pending/confirmed list
- ✅ No data mixing

**Pass Criteria:**
- [ ] Two separate trips
- [ ] Correct data for each

---

### Test 9: Permission Denial

**Objective**: Verify graceful handling of denied permissions

**Steps:**
1. Deny location permission
2. Try to start detection

**Expected Result:**
- ✅ Error message shown
- ✅ Detection doesn't start
- ✅ App doesn't crash

**Pass Criteria:**
- [ ] Error handled gracefully
- [ ] No crash

---

### Test 10: GPS Signal Loss

**Objective**: Verify handling of GPS issues

**Steps:**
1. Start detection and trip
2. Go indoors (weak GPS)
3. Come back outdoors

**Expected Result:**
- ✅ Trip continues tracking
- ✅ No crash
- ✅ Route may have gaps (acceptable)

**Pass Criteria:**
- [ ] No crash
- [ ] Trip completes

---

## 📊 Performance Testing

### Battery Usage Test

**Duration**: 24 hours

**Steps:**
1. Fully charge device
2. Start detection
3. Use phone normally for 24 hours
4. Check battery usage in settings

**Expected Result:**
- Battery drain: < 15% per day (acceptable)
- If > 20%: Optimize GPS update interval

**Pass Criteria:**
- [ ] Battery usage acceptable

---

### Memory Usage Test

**Steps:**
1. Start detection
2. Complete 10 trips
3. Check memory usage in Android Studio Profiler

**Expected Result:**
- Memory usage: < 100 MB
- No memory leaks

**Pass Criteria:**
- [ ] No memory leaks
- [ ] Memory stable

---

## 🔧 Debug Commands

### View Logs
```bash
flutter logs
```

### Check for specific logs:
```bash
flutter logs | grep "TripDetection"
```

### Clear app data:
```bash
flutter clean
flutter pub get
flutter run
```

---

## 🐛 Troubleshooting

### Issue: Detection not starting

**Check:**
1. Location permission granted?
2. GPS enabled on device?
3. Check logs for errors

**Fix:**
```bash
# Check permissions
adb shell dumpsys package com.example.tourmate | grep permission

# Restart app
flutter run
```

---

### Issue: Trip not detected

**Check:**
1. Did you move for 3+ minutes?
2. Was distance > 300 meters?
3. Was speed > 2 m/s?

**Debug:**
- Check logs for speed values
- Reduce thresholds temporarily for testing

---

### Issue: Wrong mode detected

**Expected:**
- Mode detection is ~80% accurate
- User can correct in confirmation screen

**If consistently wrong:**
- Adjust speed ranges in `TripDetectionConfig`

---

## 📝 Test Report Template

```markdown
# Trip Detection Test Report

**Date**: YYYY-MM-DD
**Tester**: Your Name
**Device**: Device Model (Android/iOS version)

## Test Results

### Test 1: Basic Trip Detection
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 2: Short Trip Rejection
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 3: Car Trip Detection
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 4: Bus Trip Detection
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 5: Trip Confirmation
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 6: Trip Rejection
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 7: Background Tracking
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 8: Multiple Trips
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 9: Permission Denial
- [ ] PASS / [ ] FAIL
- Notes: _______________

### Test 10: GPS Signal Loss
- [ ] PASS / [ ] FAIL
- Notes: _______________

## Performance

- Battery Usage: ____%
- Memory Usage: ___MB
- Crashes: ___

## Issues Found

1. _______________
2. _______________

## Recommendations

1. _______________
2. _______________

## Overall Status

- [ ] READY FOR PRODUCTION
- [ ] NEEDS FIXES
- [ ] NEEDS MORE TESTING
```

---

## 🚀 Quick Test (5 minutes)

If you have limited time, do this quick test:

1. **Connect Android device**
2. **Run app**: `flutter run`
3. **Navigate to Trip Detection screen**
4. **Start detection**
5. **Walk around your room for 5 minutes** (simulate movement)
6. **Stop for 5 minutes**
7. **Check if trip detected**

**Note**: For realistic testing, you need to actually travel (walk, drive, etc.)

---

## 📱 Recommended Test Devices

### Android
- ✅ Android 10+ (for background location)
- ✅ Good GPS accuracy
- ✅ Not in battery saver mode

### iOS
- ✅ iOS 13+
- ✅ Location services enabled

---

## 🎯 Success Criteria

The feature is ready for production if:

- ✅ 8/10 tests pass
- ✅ No critical crashes
- ✅ Battery usage < 15% per day
- ✅ Mode detection > 70% accurate
- ✅ User can correct any errors

---

## 📞 Need Help?

If tests fail or you encounter issues:

1. Check logs: `flutter logs`
2. Review documentation: `AUTOMATIC_TRIP_DETECTION.md`
3. Check troubleshooting section above
4. Adjust thresholds in `TripDetectionConfig`

---

**Testing Version**: 1.0.0  
**Last Updated**: 2025-10-08  
**Status**: Unit Tests ✅ | Device Tests ⏳ Pending
