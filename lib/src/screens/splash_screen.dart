import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ApiClient _apiClient;
  late final AuthService _authService;
  String? _errorMessage;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _apiClient = ApiClient();
    _authService = AuthService(_apiClient);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _errorMessage = null;
      _isConnecting = true;
    });

    try {
      await _authService.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final session = await _authService.restoreSession();

      if (!mounted) return;
      if (session == null) {
        _goTo(LoginScreen(apiClient: _apiClient, authService: _authService));
        return;
      }

      _goTo(
        ChatScreen(
          apiClient: _apiClient,
          authService: _authService,
          token: session.token,
          user: session.user,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _errorMessage =
            'Belum bisa terhubung ke server. Periksa internet lalu coba lagi.';
      });
    }
  }

  void _goTo(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF08090B), Color(0xFF111113), Color(0xFF08090B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: .96, end: 1.05).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF11D8C3).withValues(alpha: .35),
                        blurRadius: 42,
                        spreadRadius: 4,
                      ),
                    ],
                    image: const DecorationImage(
                      image: AssetImage('assets/branding/app_icon.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'NeuraX',
                style: TextStyle(
                  color: Color(0xFFEDEDED),
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Synchronizing neural core',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 26),
              if (_isConnecting)
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    _errorMessage ?? 'Koneksi gagal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _bootstrap,
                  child: const Text('Coba lagi'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
