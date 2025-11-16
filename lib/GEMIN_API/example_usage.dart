import 'package:flutter/material.dart';
import 'trip_planner_chat.dart';

// Example of how to use the Trip Planner Chat in your Flutter app

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Planner AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TripPlannerChat(
        apiKey: 'AIzaSyD0LzmrgGdrskcm9Dwi0-xFeRbYotrBkt8', // Your API key
      ),
    );
  }
}

// ============================================
// HOW TO INTEGRATE IN YOUR EXISTING APP
// ============================================

class MyExistingApp extends StatelessWidget {
  const MyExistingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigate to Trip Planner Chat
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TripPlannerChat(
                  apiKey: 'AIzaSyD0LzmrgGdrskcm9Dwi0-xFeRbYotrBkt8',
                ),
              ),
            );
          },
          child: const Text('Open Trip Planner'),
        ),
      ),
    );
  }
}
