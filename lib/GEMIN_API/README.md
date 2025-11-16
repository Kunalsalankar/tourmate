# Gemini AI Trip Planner for Flutter

This is a complete implementation of a Trip Planning chatbot using Google's Gemini API with direct HTTP calls in Flutter.

## 🎯 Features

- ✈️ AI-powered trip planning assistance
- 🗺️ Place recommendations
- 💬 Natural conversation interface
- 🎨 Beautiful chat UI
- 📱 Easy integration into existing Flutter apps

## 📋 Requirements

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0  # For API calls
```

Run: `flutter pub get`

## 📁 Files Included

1. **gemini_service.dart** - Service class to communicate with Gemini API
2. **chat_message.dart** - Model for chat messages
3. **trip_planner_chat.dart** - Complete chat UI widget
4. **example_usage.dart** - Examples of how to use in your app

## 🚀 How to Use

### Option 1: As a Standalone Screen

```dart
import 'package:flutter/material.dart';
import 'trip_planner_chat.dart';

void main() {
  runApp(MaterialApp(
    home: TripPlannerChat(
      apiKey: 'AIzaSyD0LzmrgGdrskcm9Dwi0-xFeRbYotrBkt8',
    ),
  ));
}
```

### Option 2: Navigate from Your Existing App

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TripPlannerChat(
      apiKey: 'AIzaSyD0LzmrgGdrskcm9Dwi0-xFeRbYotrBkt8',
    ),
  ),
);
```

### Option 3: Use Only the Service (No UI)

```dart
import 'gemini_service.dart';

final geminiService = GeminiService(
  apiKey: 'AIzaSyD0LzmrgGdrskcm9Dwi0-xFeRbYotrBkt8',
);

// Get trip advice
String response = await geminiService.getTripAdvice(
  'What are the best places to visit in Paris?'
);

print(response);
```

## 🔐 Security Note

**IMPORTANT**: Never commit your API key to version control!

### Better Approach - Use Environment Variables:

1. Create a file `lib/config.dart`:

```dart
class Config {
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'your-api-key-here',
  );
}
```

2. Use it in your code:

```dart
import 'config.dart';

TripPlannerChat(apiKey: Config.geminiApiKey)
```

3. Run with:
```bash
flutter run --dart-define=GEMINI_API_KEY=AIzaSyD0LzmrgGdrskcm9Dwi0-xFeRbYotrBkt8
```

## 💡 Example Questions to Ask

- "What are the best places to visit in Tokyo?"
- "Plan a 5-day trip to Paris"
- "Best time to visit Bali?"
- "Budget-friendly destinations in Europe"
- "What to eat in Thailand?"
- "Family-friendly activities in Dubai"

## 🎨 Customization

### Change Theme Colors

Edit `trip_planner_chat.dart`:

```dart
AppBar(
  backgroundColor: Colors.purple, // Change color here
)

// Message bubble colors
color: message.isUser ? Colors.purple : Colors.grey[200],
```

### Modify AI Behavior

Edit the prompt in `gemini_service.dart`:

```dart
String _buildTripPlannerPrompt(String userMessage) {
  return '''Your custom instructions here...''';
}
```

## 📱 Integration Steps

1. Copy all `.dart` files to your Flutter project's `lib` folder
2. Add `http: ^1.1.0` to `pubspec.yaml`
3. Run `flutter pub get`
4. Import and use `TripPlannerChat` widget
5. Pass your Gemini API key

## 🐛 Troubleshooting

### Error: "Failed to get response"
- Check your internet connection
- Verify API key is correct
- Ensure API key has Gemini API enabled

### Build Error: "http not found"
- Run `flutter pub get`
- Restart your IDE

### No Response from AI
- Check API quotas in Google Cloud Console
- Verify the API endpoint is accessible

## 📞 Support

For issues with:
- **Flutter**: Check Flutter documentation
- **Gemini API**: Visit Google AI Studio
- **This code**: Check the code comments

## 🎉 You're Ready!

Just import the widget and start using your Trip Planner AI chatbot!

```dart
import 'trip_planner_chat.dart';

// Use it anywhere in your app
TripPlannerChat(apiKey: 'YOUR_API_KEY')
```

Happy Coding! ✨
