import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/screens/home_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(
              Icons.people_alt_rounded,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(delay: 200.ms),
            const SizedBox(height: 32),
            Text(
              "Welcome to\nReady Check",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(delay: 400.ms).moveY(begin: 10, end: 0),
            const SizedBox(height: 16),
            Text(
              "Summon your squad in seconds.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ).animate().fadeIn(delay: 600.ms),
            const Spacer(),
            _GoogleSignInButton(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithGoogle();
      
      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleSignIn,
      icon: _isLoading 
        ? const SizedBox(
            width: 20, 
            height: 20, 
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
          )
        : const Icon(Icons.login), // Ideally use a Google Logo asset here
      label: Text(_isLoading ? "Signing in..." : "Sign in with Google"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        side: const BorderSide(color: Colors.black12),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(Colors.grey.shade100),
      ),
    ).animate().fadeIn(delay: 800.ms).moveY(begin: 20, end: 0);
  }
}
