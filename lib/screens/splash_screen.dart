import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/screens/onboarding_screen.dart';
import 'package:ready_check/screens/home_screen.dart'; // Keeping legacy just in case
import 'package:ready_check/screens/main_screen.dart';
import 'package:ready_check/screens/session/ready_check_overlay.dart';
import 'package:ready_check/services/session_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for animation to be perceptible
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final sessionService = Provider.of<SessionService>(context, listen: false);
    
    if (authService.isAuthenticated) {
        // Always go to MainScreen. 
        // Logic for rejoining session should be handled by MainScreen listener or Lobby.
        // This fixes the "Blank Screen" bug (pop from replacement) and "Phantom Summon" (stale session).
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
        /*
        final activeSessionId = await sessionService.checkCurrentSession();
        if (activeSessionId != null) {
           Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ReadyCheckOverlay(sessionId: activeSessionId)),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
        */
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_esports_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(
              duration: 1.5.seconds,
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.1, 1.1),
              curve: Curves.easeInOut,
            ),
            const SizedBox(height: 24),
            Text(
              "Ready Check",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ).animate().fadeIn(duration: 800.ms).moveY(
                  begin: 20,
                  end: 0,
                  curve: Curves.easeOut,
                ),
          ],
        ),
      ),
    );
  }
}
