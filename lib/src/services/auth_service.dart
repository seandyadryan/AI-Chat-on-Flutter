import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/session_user.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this._apiClient) : _googleSignIn = GoogleSignIn.instance;

  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  Future<void> initialize() async {
    await _googleSignIn.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
  }

  Future<AuthSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final rawUser = prefs.getString(_userKey);

    if (token == null || rawUser == null) return null;

    return AuthSession(
      token: token,
      user: SessionUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>),
    );
  }

  Future<AuthSession> signIn() async {
    final account = await _googleSignIn.authenticate();
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const ApiException('Google ID token tidak tersedia.');
    }

    final session = await _apiClient.loginWithGoogle(idToken);
    await _saveSession(session);
    return session;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await _googleSignIn.signOut();
  }

  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': session.user.id,
        'name': session.user.name,
        'email': session.user.email,
        'photoUrl': session.user.photoUrl,
      }),
    );
  }
}
