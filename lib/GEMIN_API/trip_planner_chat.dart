import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/device_location_service.dart';
import '../services/places_service.dart';
import 'chat_message.dart';

class TripPlannerChat extends StatefulWidget {
  const TripPlannerChat({Key? key}) : super(key: key);

  @override
  State<TripPlannerChat> createState() => _TripPlannerChatState();
}

class _TripPlannerChatState extends State<TripPlannerChat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  final DeviceLocationService _locationService = DeviceLocationService();
  final PlacesService _placesService = PlacesService();

  Position? _currentPosition;
  List<PlaceResult> _currentPlaces = [];
  double? _selectedDistanceKm;
  String? _selectedMode;

  _ChatStep _step = _ChatStep.intro;

  @override
  void initState() {
    super.initState();
    _initializeAssistant();
  }

  Future<void> _initializeAssistant() async {
    final hasPermission = await _locationService.ensurePermissions();

    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Hi! I\'m your Online Travel Assistant. To help you find nearby places, please enable location services and grant permission in your device settings.',
            isUser: false,
          ),
        );
      });
      return;
    }

    final pos = await _locationService.getCurrentPosition();

    if (!mounted) return;

    setState(() {
      _currentPosition = pos;
      _messages.add(
        ChatMessage(
          text:
              "Hi! I'm your Online Travel Assistant. I use your real location to help you find nearby places like hospitals, temples, fuel stations, ATMs, and tourist spots.\n\n"
              "Ask me anything like:\n"
              "• Nearest hospital\n"
              "• Nearest temple\n"
              "• Nearest petrol pump\n"
              "• Best travel mode\n"
              "• Estimated travel time",
          isUser: false,
        ),
      );
      _step = _ChatStep.awaitingQuery;
    });
  }
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
    });

    _handleUserMessage(userMessage);

    _scrollToBottom();
  }

  Future<void> _handleUserMessage(String text) async {
    switch (_step) {
      case _ChatStep.intro:
      case _ChatStep.awaitingQuery:
        await _handleQueryStep(text);
        break;
      case _ChatStep.awaitingPlaceSelection:
        _handlePlaceSelectionStep(text);
        break;
      case _ChatStep.awaitingTravelMode:
        _handleTravelModeStep(text);
        break;
      case _ChatStep.askAnother:
        _handleAskAnotherStep(text);
        break;
    }
    _scrollToBottom();
  }

  Future<void> _handleQueryStep(String text) async {
    final q = text.toLowerCase();

    if (_currentPosition == null) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'I could not access your current location. Please ensure GPS is enabled and try again.',
            isUser: false,
          ),
        );
      });
      return;
    }

    String? keyword;
    String categoryLabel = 'places';

    if (q.contains('hospital')) {
      keyword = 'hospital';
      categoryLabel = 'hospitals';
    } else if (q.contains('temple')) {
      keyword = 'temple';
      categoryLabel = 'temples';
    } else if (q.contains('petrol') || q.contains('fuel')) {
      keyword = 'petrol pump';
      categoryLabel = 'petrol pumps';
    } else if (q.contains('atm')) {
      keyword = 'atm';
      categoryLabel = 'ATMs';
    } else if (q.contains('tourist')) {
      keyword = 'tourist attraction';
      categoryLabel = 'tourist spots';
    }

    if (keyword == null) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Please ask for something like "nearest hospital", "nearest temple", "nearest petrol pump", "nearest ATM" or "nearest tourist spot".',
            isUser: false,
          ),
        );
      });
      return;
    }

    setState(() {
      _messages.add(
        ChatMessage(
          text: 'Searching for nearby $categoryLabel using your current location...',
          isUser: false,
        ),
      );
    });

    final results = await _placesService.searchNearby(
      position: _currentPosition!,
      keyword: keyword,
      limit: 5,
    );

    if (!mounted) return;

    if (results.isEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'I could not find any nearby $categoryLabel right now. Please try again later or check your internet connection.',
            isUser: false,
          ),
        );
      });
      return;
    }

    _currentPlaces = results;

    final buffer = StringBuffer('Here are the nearest $categoryLabel:\n');
    for (var i = 0; i < results.length; i++) {
      buffer.writeln('${i + 1}. ${results[i].name}');
    }
    buffer.writeln('\nSelect a number to continue.');

    setState(() {
      _messages.add(
        ChatMessage(
          text: buffer.toString(),
          isUser: false,
        ),
      );
      _step = _ChatStep.awaitingPlaceSelection;
    });
  }

  void _handlePlaceSelectionStep(String text) {
    final index = int.tryParse(text.trim());
    if (index == null || index < 1 || index > _currentPlaces.length) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Please select a valid number between 1 and ${_currentPlaces.length}.',
            isUser: false,
          ),
        );
      });
      return;
    }

    final place = _currentPlaces[index - 1];

    if (_currentPosition == null) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'I lost access to your location. Please try your request again.',
            isUser: false,
          ),
        );
      });
      return;
    }

    final meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      place.lat,
      place.lng,
    );
    final km = meters / 1000.0;
    _selectedDistanceKm = km;

    setState(() {
      _messages.add(
        ChatMessage(
          text:
              '${place.name} is ${km.toStringAsFixed(1)} km away from your current location.',
          isUser: false,
        ),
      );
      _messages.add(
        ChatMessage(
          text:
              'How would you like to travel?\n1. Car\n2. Bike\n3. Bus\n4. Walk',
          isUser: false,
        ),
      );
      _step = _ChatStep.awaitingTravelMode;
    });
  }

  void _handleTravelModeStep(String text) {
    final q = text.toLowerCase().trim();

    String mode;
    double speedKmh;

    if (q == '1' || q.contains('car')) {
      mode = 'Car';
      speedKmh = 40;
    } else if (q == '2' || q.contains('bike')) {
      mode = 'Bike';
      speedKmh = 35;
    } else if (q == '3' || q.contains('bus')) {
      mode = 'Bus';
      speedKmh = 25;
    } else if (q == '4' || q.contains('walk')) {
      mode = 'Walk';
      speedKmh = 5;
    } else {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Please choose 1 for Car, 2 for Bike, 3 for Bus or 4 for Walk.',
            isUser: false,
          ),
        );
      });
      return;
    }

    _selectedMode = mode;

    final distanceKm = _selectedDistanceKm ?? 0;
    final hours = distanceKm / speedKmh;
    final minutes = (hours * 60).round();

    setState(() {
      _messages.add(
        ChatMessage(
          text: 'By $mode, you will reach in approx $minutes minutes.',
          isUser: false,
        ),
      );
      _messages.add(
        ChatMessage(
          text: 'Would you like to find another location? (Yes / No)',
          isUser: false,
        ),
      );
      _step = _ChatStep.askAnother;
    });
  }

  void _handleAskAnotherStep(String text) {
    final q = text.toLowerCase().trim();

    if (q == 'yes' || q == 'y') {
      _currentPlaces = [];
      _selectedDistanceKm = null;
      _selectedMode = null;

      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Okay! Ask me again, for example: "nearest hospital", "nearest temple" or "nearest petrol pump".',
            isUser: false,
          ),
        );
        _step = _ChatStep.awaitingQuery;
      });
    } else if (q == 'no' || q == 'n') {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Glad I could help. If you need assistance again, just reopen the Travel Assistant.',
            isUser: false,
          ),
        );
        _step = _ChatStep.awaitingQuery;
      });
    } else {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Please reply with Yes or No.',
            isUser: false,
          ),
        );
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Assistant'),
        backgroundColor: Colors.blue,
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(message.isUser),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (message.isUser) _buildAvatar(message.isUser),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return CircleAvatar(
      backgroundColor: isUser ? Colors.blue : Colors.green,
      radius: 16,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 20,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask about trip destinations...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

enum _ChatStep {
  intro,
  awaitingQuery,
  awaitingPlaceSelection,
  awaitingTravelMode,
  askAnother,
}
