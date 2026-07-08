import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.apiClient,
    required this.authService,
    super.key,
  });

  final ApiClient apiClient;
  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;
  String? _error;

  Future<void> _signIn() async {
    if (_isSigningIn) return;
    setState(() {
      _isSigningIn = true;
      _error = null;
    });

    try {
      final session = await widget.authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            apiClient: widget.apiClient,
            authService: widget.authService,
            token: session.token,
            user: session.user,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset(
                'assets/branding/app_icon.png',
                width: 190,
                height: 190,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 28),
              const Text(
                'NeuraX',
                style: TextStyle(
                  color: Color(0xFFEDEDED),
                  fontSize: 62,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Understand the universe_',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFB8B8B8),
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 66,
                child: FilledButton.icon(
                  onPressed: _isSigningIn ? null : _signIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF202124),
                    disabledBackgroundColor: const Color(0xFF202124),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(33),
                    ),
                  ),
                  icon: _isSigningIn
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _DisabledLoginButton(
                icon: Icons.alternate_email_rounded,
                label: 'Continue with Email',
              ),
              const SizedBox(height: 14),
              _DisabledLoginButton(
                icon: Icons.close_rounded,
                label: 'Continue with X',
              ),
              if (_error != null) ...[
                const SizedBox(height: 22),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFF6B6B)),
                ),
              ],
              const Spacer(),
              const Text.rich(
                TextSpan(
                  text: 'By continuing you agree to ',
                  children: [
                    TextSpan(
                      text: 'Terms',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: '\nand '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF77787D), fontSize: 15),
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisabledLoginButton extends StatelessWidget {
  const _DisabledLoginButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: const Color(0xFF15161A),
          disabledForegroundColor: const Color(0xFF55565C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
