# Notification Testing Guide

## 🧪 How to Test Trip Notifications

### Step 1: Check Logs When Creating a Trip

When you create a future trip, you should see these logs in your console:

```
🚀 [TRIP_CUBIT] Creating trip...
   Trip Number: TRIP001
   Trip Type: TripType.future
   Trip Time: 2025-10-09 17:45:00.000
   Origin: Mumbai
   Destination: Pune
   ✅ Trip created with ID: abc123
   📲 Scheduling notifications for future trip...

🔔 [SCHEDULER] scheduleNotificationsForTrip called
   Trip ID: abc123
   Trip Type: TripType.future
   Include Reminder: true
   📱 Scheduling trip start notification...

📅 [NOTIFICATION] Attempting to schedule trip notification
   Trip ID: abc123
   Trip Type: TripType.future
   Trip Time: 2025-10-09 17:45:00.000
   Scheduled Date: 2025-10-09 17:45:00.000+05:30
   Current Time: 2025-10-09 17:30:00.000+05:30
   Time Until Trip: 15 minutes
   Notification ID: 123456789
   ✅ Trip notification scheduled successfully!

   ⏰ Scheduling reminder notification...

⏰ [NOTIFICATION] Attempting to schedule reminder notification
   Reminder Before: 60 minutes
   Reminder Time: 2025-10-09 16:45:00.000+05:30
   Current Time: 2025-10-09 17:30:00.000+05:30
   ❌ Reminder time has passed, skipping

   ✅ All notifications scheduled successfully!
   ✅ Notifications scheduled
```

### Step 2: Test with Short Time Intervals

**To test notifications quickly (2-3 minutes from now):**

1. **Create a future trip** with these settings:
   - Trip Type: **Future**
   - Date: **Today**
   - Time: **3 minutes from current time**
   - Example: If it's 5:30 PM now, set time to 5:33 PM

2. **Save the trip**

3. **Check the logs** - You should see:
   - ✅ Trip notification scheduled successfully
   - ❌ Reminder time has passed (this is normal for short intervals)

4. **Wait 3 minutes** - You should receive notification at the exact time

### Step 3: Check Pending Notifications

Add this code temporarily to check if notifications are actually scheduled:

```dart
// In your trip creation success handler
final notificationService = NotificationService();
final pending = await notificationService.getPendingNotifications();
print('📋 Pending notifications: ${pending.length}');
for (final n in pending) {
  print('   - ID: ${n.id}, Title: ${n.title}');
}
```

---

## 🔍 Troubleshooting

### Issue 1: No Logs Appearing

**Problem:** You don't see any notification logs when creating a trip.

**Solutions:**
1. Make sure you selected **"Future"** as trip type
2. Check that the trip time is in the future
3. Verify notification scheduler is passed to TripCubit in `app.dart`

### Issue 2: "Notification scheduler is null"

**Problem:** Log shows `⚠️ Notification scheduler is null!`

**Solution:** Check `lib/app/app.dart` - ensure `tripNotificationScheduler` is passed to TripCubit:

```dart
BlocProvider(
  create: (_) => TripCubit(
    tripRepository: TripRepository(),
    notificationScheduler: tripNotificationScheduler, // ← Must be here
  ),
),
```

### Issue 3: "Trip time has passed"

**Problem:** Log shows `❌ Trip time has passed, skipping notification`

**Solution:** The trip time you selected is in the past. Set a future time.

### Issue 4: Notification Scheduled But Not Received

**Possible Causes:**

1. **Permissions not granted**
   - Check: Settings → Apps → Tourmate → Notifications → Enabled?
   - Check: Settings → Apps → Tourmate → Alarms & Reminders → Allowed?

2. **Battery Optimization**
   - Go to: Settings → Battery → Battery Optimization
   - Find "Tourmate" → Set to "Don't optimize"

3. **MIUI/Xiaomi Specific**
   - Settings → Apps → Manage Apps → Tourmate
   - Enable "Autostart"
   - Enable "Display pop-up windows while running in background"
   - Battery Saver → No restrictions

4. **Android 13+ Permission**
   - Make sure you clicked "Enable" on the permission dialog
   - Check: Settings → Apps → Tourmate → Notifications

---

## 📱 Quick Test Procedure

### 5-Minute Test:

1. **Open the app** (first time users will see permission dialog → Click "Enable")

2. **Create a future trip:**
   - Trip Number: TEST001
   - Origin: Any location
   - Destination: Any location
   - Trip Type: **Future** ← IMPORTANT!
   - Date: Today
   - Time: **Current time + 5 minutes**
   - Mode: Any
   - Click "Create Trip"

3. **Check console logs:**
   ```
   ✅ Trip notification scheduled successfully!
   ```

4. **Lock your phone** (to simulate background)

5. **Wait 5 minutes**

6. **Expected result:** You should see notification:
   ```
   Trip Starting Now! 🚀
   Your trip from [Origin] to [Destination] is starting now. Have a safe journey!
   ```

---

## 🐛 Common Errors and Fixes

### Error: "PlatformException"

```
❌ Error scheduling notification: PlatformException(...)
```

**Fix:** Check AndroidManifest.xml has these permissions:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
```

### Error: "Timezone not initialized"

```
❌ Error: The 'tz' database has not been initialized
```

**Fix:** Check `main.dart` has:
```dart
tz.initializeTimeZones();
```

### Error: "Cannot schedule in the past"

```
❌ Trip time has passed, skipping notification
```

**Fix:** Set trip time to future (at least 1 minute from now)

---

## 📊 Verification Checklist

Before testing, verify:

- [ ] `shared_preferences` dependency added to `pubspec.yaml`
- [ ] `flutter pub get` executed
- [ ] Notification permissions granted (check on first launch)
- [ ] Trip type set to **"Future"**
- [ ] Trip time is in the future
- [ ] Battery optimization disabled for the app
- [ ] App has notification permissions (Android 13+)

---

## 🎯 Expected Behavior

### For a trip scheduled 10 minutes from now:

| Time | Event |
|------|-------|
| T-10 min | Trip created, notification scheduled |
| T-1 hour | ❌ Reminder skipped (time passed) |
| T (exact time) | ✅ Notification appears |

### For a trip scheduled tomorrow at 10:00 AM:

| Time | Event |
|------|-------|
| Today | Trip created, notifications scheduled |
| Tomorrow 9:00 AM | ✅ Reminder notification appears |
| Tomorrow 10:00 AM | ✅ Trip start notification appears |

---

## 💡 Pro Tips

1. **Test with short intervals first** (2-5 minutes) to verify it works
2. **Check logs immediately** after creating trip
3. **Keep app in background** during test (lock phone)
4. **Use Logcat** to see all logs: `flutter logs` or Android Studio Logcat
5. **Test on real device** (emulator may have timing issues)

---

## 🔧 Debug Commands

### View all pending notifications:
```dart
final service = NotificationService();
final pending = await service.getPendingNotifications();
print('Pending: ${pending.length}');
```

### Cancel all notifications:
```dart
final service = NotificationService();
await service.cancelAllNotifications();
```

### Reset first-launch flag:
```dart
final prefs = PreferencesService();
await prefs.initialize();
await prefs.reset();
```

---

## ✅ Success Indicators

You'll know it's working when you see:

1. ✅ Logs show "Trip notification scheduled successfully!"
2. ✅ Notification appears at exact scheduled time
3. ✅ Tapping notification opens the app
4. ✅ Notification works even when app is closed

---

**Need Help?**
- Check the logs for error messages
- Verify all permissions are granted
- Test with a very short time interval (2-3 minutes)
- Make sure trip type is "Future"
