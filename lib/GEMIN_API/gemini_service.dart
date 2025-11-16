import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String role; // 'user' or 'model'
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toContentPart() {
    return {
      'role': role,
      'parts': [
        {'text': content}
      ]
    };
  }
}

class GeminiService {
  final String apiKey;
  List<String> _candidateEndpoints = [
    'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent',
    'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent',
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
  ];
  bool _endpointsAugmented = false;

  GeminiService({required this.apiKey});

  Future<void> _augmentEndpointsFromListModels() async {
    if (_endpointsAugmented) return;
    _endpointsAugmented = true;

    final priorities = <String>[
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-1.5-pro-002',
      'gemini-1.5-pro-001',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
      'gemini-pro',
    ];

    Future<List<String>> listModels(String version) async {
      final url = Uri.parse('https://generativelanguage.googleapis.com/$version/models?key=$apiKey');
      try {
        final res = await http.get(url);
        if (res.statusCode != 200) return [];
        final data = jsonDecode(res.body);
        final models = (data['models'] as List?) ?? [];
        return models.map<String>((m) => m['name'] as String).toList();
      } catch (_) {
        return [];
      }
    }

    final v1 = await listModels('v1');
    final v1beta = await listModels('v1beta');

    String? pickModel(String version, List<String> names) {
      for (final p in priorities) {
        final target = 'models/$p';
        if (names.contains(target)) {
          return 'https://generativelanguage.googleapis.com/$version/$target:generateContent';
        }
      }
      return null;
    }

    final chosenV1 = pickModel('v1', v1);
    final chosenV1beta = pickModel('v1beta', v1beta);

    final additions = <String>[];
    if (chosenV1 != null) additions.add(chosenV1);
    if (chosenV1beta != null) additions.add(chosenV1beta);

    // Prepend discovered endpoints so they are tried first
    if (additions.isNotEmpty) {
      _candidateEndpoints = [...additions, ..._candidateEndpoints];
    }
  }

  Future<http.Response> _postGenerate(Map<String, dynamic> body) async {
    await _augmentEndpointsFromListModels();
    Exception? lastError;
    for (final base in _candidateEndpoints) {
      final url = Uri.parse('$base?key=$apiKey');
      try {
        final res = await http.post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (res.statusCode == 200) return res;
        // Some 4xx/5xx may be model-specific; try next
        lastError = Exception('HTTP ${res.statusCode}: ${res.body} @ $base');
      } catch (e) {
        lastError = Exception('Request error @ $base: $e');
      }
    }
    throw lastError ?? Exception('No endpoint succeeded');
  }

  /// Send a message to Gemini API and get trip planning advice
  Future<String> getTripAdvice(String userMessage) async {
    try {
      final response = await _postGenerate({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': _buildTripPlannerPrompt(userMessage)}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      });

      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      return text;
    } catch (e) {
      throw Exception('Error communicating with Gemini API: $e');
    }
  }

  /// Build a specialized prompt for trip planning
  String _buildTripPlannerPrompt(String userMessage) {
    return '''You are a helpful travel assistant AI. Your role is to provide trip planning advice, 
suggest places to visit, recommend activities, provide travel tips, and help users plan their perfect trip.

When users ask about destinations, provide:
- Top places to visit
- Best time to visit
- Local attractions and activities
- Food recommendations
- Approximate budget estimates
- Travel tips and safety information

User question: $userMessage''';
  }

  /// Get conversation-based response (for chat history)
  Future<String> getChatResponse(List<Map<String, String>> chatHistory, String newMessage) async {
    try {
      // Build contents with chat history
      List<Map<String, dynamic>> contents = [];
      
      // Add system prompt
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': 'You are a helpful travel assistant. Provide trip planning advice and destination recommendations.'
          }
        ]
      });
      
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text': 'Hello! I\'m your travel assistant. I can help you plan trips, suggest destinations, and provide travel advice. Where would you like to go?'
          }
        ]
      });
      
      // Add chat history
      for (var message in chatHistory) {
        contents.add({
          'role': message['role'],
          'parts': [
            {'text': message['content']}
          ]
        });
      }
      
      // Add new message
      contents.add({
        'role': 'user',
        'parts': [
          {'text': newMessage}
        ]
      });
      
      final response = await _postGenerate({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.8,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        }
      });

      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      return text;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Chat with a list of ChatMessage objects (history already prepared)
  Future<String> chat(List<ChatMessage> messages) async {
    try {
      final contents = messages.map((m) => m.toContentPart()).toList();
      final response = await _postGenerate({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.8,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        }
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        return text;
      } else {
        throw Exception('Failed to get response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Convenience: pass history and a new user message; returns the model reply
  Future<String> chatWithUserMessage(List<ChatMessage> history, String userMessage) async {
    final all = List<ChatMessage>.from(history)
      ..add(ChatMessage(role: 'user', content: userMessage));
    return chat(all);
  }
}
