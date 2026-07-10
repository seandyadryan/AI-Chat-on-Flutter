import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import '../config/app_config.dart';
import '../models/session_user.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this._apiClient) : _googleSignIn = GoogleSignIn.instance;

  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await _googleSignIn.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
    _initialized = true;
  }

  Future<AuthSession?> restoreSession() async {
    await initialize();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    final idToken = await firebaseUser.getIdToken();
    if (idToken == null) return null;

    final session = await _apiClient.loginWithFirebase(idToken);
    await _saveSession(session);
    return session;
  }

  Future<AuthSession> signInWithGoogle() async {
    await initialize();
    final account = await _authenticateGoogle();
    final googleAuth = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final firebaseCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final idToken = await firebaseCredential.user?.getIdToken();
    if (idToken == null) {
      throw const ApiException('Token Firebase tidak tersedia.');
    }

    final session = await _apiClient.loginWithFirebase(idToken);
    await _saveSession(session);
    return session;
  }

  Future<GoogleSignInAccount> _authenticateGoogle() async {
    try {
      return await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (!_isAccountReauthFailure(error)) rethrow;

      await _clearGoogleSession();

      try {
        return await _googleSignIn.authenticate();
      } on GoogleSignInException catch (retryError) {
        if (_isAccountReauthFailure(retryError)) {
          throw const ApiException(
            'Sesi akun Google di perangkat gagal diperbarui. Coba hapus akun Google dari HP lalu login ulang, atau pilih akun Google lain.',
          );
        }
        rethrow;
      }
    }
  }

  bool _isAccountReauthFailure(GoogleSignInException error) {
    return error.code == GoogleSignInExceptionCode.canceled &&
        (error.description ?? '').toLowerCase().contains(
          'account reauth failed',
        );
  }

  Future<void> _clearGoogleSession() async {
    await FirebaseAuth.instance.signOut();
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
  }

  Future<AuthSession?> cachedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final rawUser = prefs.getString(_userKey);

    if (token == null || rawUser == null) return null;

    return AuthSession(
      token: token,
      user: SessionUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>),
    );
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
