import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../models/session_user.dart';

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final SessionUser user;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<AuthSession> loginWithFirebase(String idToken) async {
    final response = await _client
        .post(
          _uri('/auth/firebase'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 20));

    final json = _decode(response);
    return AuthSession(
      token: json['token'] as String,
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Future<List<ChatMessage>> getMessages(String token) async {
    final response = await _client
        .get(_uri('/chat/messages'), headers: _authHeaders(token))
        .timeout(const Duration(seconds: 20));

    final json = _decode(response);
    return (json['messages'] as List<dynamic>)
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String token,
    required String message,
  }) async {
    final response = await _client
        .post(
          _uri('/chat/messages'),
          headers: _authHeaders(token),
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 60));

    final json = _decode(response);
    return ChatMessage.fromJson(json['assistant'] as Map<String, dynamic>);
  }

  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(body['error'] as String? ?? 'Request failed');
    }

    return body;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
