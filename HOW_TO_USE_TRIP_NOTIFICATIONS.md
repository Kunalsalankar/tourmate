# 📱 How to Use Trip Detection Notifications

## 🎯 Quick Start Guide

Trip detection notifications automatically alert you when the app detects your journeys. Here's everything you need to know!

---

## ✨ What You'll Get

### **When a Trip Starts** 🚗
You'll receive a notification like:
```
🚗 New Trip Detected!
Started Car from Mumbai, Maharashtra. Tracking your journey...
```

### **When a Trip Ends** ✅
You'll receive a notification like:
```
✅ Trip Completed!
Car trip ended at Pune, Maharashtra. 145.23km in 2h 30min
```

---

## 🚀 Setup (First Time Only)

### **Step 1: Enable Notifications**
When you first open the app, you'll be asked to allow notifications:
1. Tap **"Allow"** when prompted
2. If you missed it, go to device Settings → Apps → TourMate → Notifications → Enable

### **Step 2: Enable Trip Detection**
1. Open the TourMate app
2. Go to **Trip Detection** screen
3. Tap **"Start Detection"** button
4. Grant location permissions if asked

### **Step 3: You're Ready!**
That's it! The app will now automatically detect your trips and send notifications.

---

## 📲 How It Works

### **Automatic Detection**
The app uses your phone's GPS to detect when you're traveling:

1. **Movement Detected** (1 minute)
   - App notices you're moving
   - Waits 1 minute to confirm
   - Sends "Trip Detected" notification 🚗

2. **Journey Tracked**
   - Records your route
   - Calculates distance
   - Detects travel mode (car, bike, bus, etc.)

3. **Stopped** (5 minutes)
   - App notices you've stopped
   - Waits 5 minutes to confirm
   - Sends "Trip Completed" notification ✅

---

## 🎨 Notification Types

### **1. Trip Start Notification**
- **When**: After 1 minute of continuous movement
- **Shows**: Travel mode + Origin location
- **Sound**: Yes 🔔
- **Vibration**: Yes 📳
- **Example**: "Started Car from Mumbai, Maharashtra"

### **2. Trip End Notification**
- **When**: After 5 minutes of being stationary
- **Shows**: Mode + Destination + Distance + Duration
- **Sound**: Yes 🔔
- **Vibration**: Yes 📳
- **Example**: "Car trip ended at Pune. 145km in 2h 30min"

### **3. Trip Update** (Optional)
- **When**: During long trips (every 15 minutes)
- **Shows**: Current distance and duration
- **Sound**: No 🔕
- **Vibration**: No
- **Example**: "Car • 45.5km • 1h 15min"

---

## ⚙️ Customization

### **Notification Settings**

#### **Android**
```
Settings → Apps → TourMate → Notifications
```

You can customize:
- ✅ **Trip Detection** - Start/End notifications (High priority)
- ✅ **Trip Updates** - Ongoing trip progress (Low priority)
- ✅ Sound, Vibration, Pop-up behavior

#### **iOS**
```
Settings → Notifications → TourMate
```

You can customize:
- ✅ Allow Notifications
- ✅ Sounds
- ✅ Badges
- ✅ Show on Lock Screen

---

## 🔕 Quiet Hours

### **Don't Want Notifications at Night?**

#### **Android**
```
Settings → Sound → Do Not Disturb
→ Set schedule (e.g., 10 PM - 7 AM)
→ Add TourMate to exceptions if needed
```

#### **iOS**
```
Settings → Focus → Do Not Disturb
→ Set schedule
→ Allow notifications from TourMate if needed
```

---

## 🎯 Travel Modes Detected

The app automatically detects your travel mode:

| Mode | Speed Range | Icon |
|------|-------------|------|
| **Walking** | 0-7 km/h | 🚶 |
| **Cycling** | 7-25 km/h | 🚴 |
| **E-Bike** | 12-25 km/h | 🛵 |
| **Motorcycle** | 25-60 km/h | 🏍️ |
| **Car** | 40-120 km/h | 🚗 |
| **Bus** | 30-80 km/h | 🚌 |
| **Train** | 80+ km/h | 🚆 |

---

## 💡 Tips & Tricks

### **Get Better Location Names**
- ✅ Keep internet connection active
- ✅ Enable high accuracy location
- ✅ The app uses Google's geocoding for accurate names

### **Save Battery**
- ⚡ Trip detection uses optimized GPS
- ⚡ Only updates location every 30 seconds
- ⚡ Automatically stops when stationary

### **Avoid False Detections**
- 🎯 App waits 1 minute before starting trip
- 🎯 App waits 5 minutes before ending trip
- 🎯 Short movements (<300m) are ignored

---

## 🐛 Troubleshooting

### **Not Getting Notifications?**

#### **Check Notification Permission**
```
Settings → Apps → TourMate → Notifications → Enabled ✅
```

#### **Check Battery Optimization**
```
Settings → Battery → Battery Optimization
→ Find TourMate → Don't optimize
```

#### **Check Background Restrictions**
```
Settings → Apps → TourMate → Battery
→ Background restriction → Unrestricted
```

### **Wrong Location Names?**

#### **Check Internet Connection**
- Reverse geocoding needs internet
- Falls back to coordinates if offline

#### **Check Location Accuracy**
```
Settings → Location → Location Services
→ Mode → High accuracy
```

### **Notifications Delayed?**

#### **Disable Battery Saver**
- Battery saver can delay background tasks
- Disable for TourMate specifically

#### **Check App Permissions**
```
Settings → Apps → TourMate → Permissions
→ Location → Allow all the time
```

---

## 📊 Understanding Your Notifications

### **Notification Details Explained**

#### **"Started Car from Mumbai, Maharashtra"**
- **Car** = Detected travel mode
- **Mumbai, Maharashtra** = Your starting location (from GPS)

#### **"145.23km in 2h 30min"**
- **145.23km** = Total distance traveled
- **2h 30min** = Total trip duration

#### **"Car • 45.5km • 1h 15min"** (Ongoing)
- **Car** = Current travel mode
- **45.5km** = Distance so far
- **1h 15min** = Duration so far

---

## 🔐 Privacy

### **Your Data is Safe**
- ✅ Notifications are local only
- ✅ No data sent to external servers
- ✅ Location used only for trip tracking
- ✅ You control all permissions

### **What We Track**
- ✅ GPS coordinates (for route)
- ✅ Travel speed (for mode detection)
- ✅ Trip start/end times

### **What We DON'T Track**
- ❌ Your personal information
- ❌ Your contacts
- ❌ Your messages
- ❌ Other app usage

---

## 🎓 Best Practices

### **For Accurate Tracking**
1. ✅ Keep location services enabled
2. ✅ Use high accuracy mode
3. ✅ Keep internet connection active
4. ✅ Don't force close the app

### **For Better Battery Life**
1. ⚡ Use battery optimization for other apps
2. ⚡ Disable trip detection when not traveling
3. ⚡ Close other background apps

### **For Better Notifications**
1. 🔔 Enable all notification channels
2. 🔔 Set high priority for trip detection
3. 🔔 Allow pop-up notifications
4. 🔔 Enable lock screen notifications

---

## 📞 Need Help?

### **Common Questions**

**Q: Can I disable notifications?**
A: Yes! Go to Settings → Apps → TourMate → Notifications → Disable

**Q: Will this drain my battery?**
A: No! The app uses optimized GPS and only updates every 30 seconds.

**Q: Can I customize notification sounds?**
A: Yes! Go to notification channel settings and choose your sound.

**Q: Why do I get notifications late?**
A: Check battery optimization and background restrictions.

**Q: Can I see past notifications?**
A: Yes! Swipe down notification shade to see notification history.

---

## 🎉 Enjoy Your Trips!

With trip detection notifications, you'll never miss a journey. The app works silently in the background and alerts you at the right moments.

**Happy Traveling!** 🚗✨

---

**Last Updated**: October 14, 2025
**App Version**: 1.0.0
