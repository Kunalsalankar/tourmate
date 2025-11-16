# 🚀 Quick Start Guide

## Step 1: Add Dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
```

Run:
```bash
flutter pub get
```

## Step 2: Copy Files

Copy these 3 files to your Flutter project's `lib` folder:
- `gemini_service.dart`
- `chat_message.dart`
- `trip_planner_chat.dart`

## Step 3: Use in Your App

### Simple Usage:

```dart
import 'package:flutter/material.dart';
import 'trip_planner_chat.dart';

// In any widget, navigate to the chat:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TripPlannerChat(
      apiKey: 'AIzaSyD0LzmrgGdrskcm9Dwi0-xFeRbYotrBkt8',
    ),
  ),
);
```

## That's It! 🎉

Your Trip Planner AI chatbot is ready to use.

## Example Questions:

- "Best places to visit in Japan?"
- "Plan a 7-day trip to Italy"
- "Budget hotels in Paris"
- "What to eat in Thailand?"

## Need Help?

Check `README.md` for detailed documentation.
