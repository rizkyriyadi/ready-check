import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/session_model.dart';
import 'package:ready_check/models/lobby_model.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/services/session_service.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum ReadyCheckResult { pending, success, failed }

class ReadyCheckOverlay extends StatefulWidget {
  final String sessionId;

  const ReadyCheckOverlay({super.key, required this.sessionId});

  @override
  State<ReadyCheckOverlay> createState() => _ReadyCheckOverlayState();
}

class _ReadyCheckOverlayState extends State<ReadyCheckOverlay> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _timer;
  int _secondsRemaining = 30;
  bool _hasResponded = false;
  ReadyCheckResult _result = ReadyCheckResult.pending;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _playSound();
  }

  void _playSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/summon_sound.mp3'));
    } catch (e) {
      debugPrint("Audio Play Error (Ignored): $e");
    }
  }

  void _stopSound() {
    try {
      _audioPlayer.stop();
    } catch (e) {
      // Ignore
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _stopSound();
        if (_result == ReadyCheckResult.pending) {
          _showResult(ReadyCheckResult.failed);
        }
      }
    });
  }

  void _checkResult(List<Participant> participants) {
    if (_resultShown || participants.isEmpty) return;

    final allVoted = participants.every((p) => p.status == 'ready' || p.status == 'declined');
    if (!allVoted) return;

    final allReady = participants.every((p) => p.status == 'ready');
    _showResult(allReady ? ReadyCheckResult.success : ReadyCheckResult.failed);
  }

  void _showResult(ReadyCheckResult result) {
    if (_resultShown) return;
    _resultShown = true;
    _timer?.cancel();
    _stopSound();
    
    setState(() => _result = result);
    HapticFeedback.heavyImpact();

    // Auto close after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopSound();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.user;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
         if (didPop) _stopSound();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: _result == ReadyCheckResult.pending ? AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ) : null,
        body: StreamBuilder<Session>(
          stream: sessionService.streamSession(widget.sessionId),
          builder: (context, sessionSnap) {
            if (!sessionSnap.hasData) return const Center(child: CircularProgressIndicator());
            final session = sessionSnap.data!;
            
            return StreamBuilder<List<Participant>>(
              stream: sessionService.streamSessionParticipants(widget.sessionId),
              builder: (context, participantsSnap) {
                 final participants = participantsSnap.data ?? [];
                 
                 // Update my response status
                 final me = participants.firstWhere((p) => p.uid == currentUser?.uid, orElse: () => Participant(uid: '', displayName: '', photoUrl: ''));
                 if ((me.status == 'ready' || me.status == 'declined') && !_hasResponded) {
                    _hasResponded = true;
                    _stopSound();
                 }

                 // Check for result
                 WidgetsBinding.instance.addPostFrameCallback((_) => _checkResult(participants));

                 // Result Screen
                 if (_result != ReadyCheckResult.pending) {
                   return _ResultScreen(result: _result);
                 }

                 return Stack(
                   children: [
                      // Background Gradient
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF0F172A), Colors.black]
                            )
                          ),
                        ),
                      ),
                      
                      SafeArea(
                        child: Column(
                          children: [
                             const SizedBox(height: 40),
                             
                             // Header
                             const Text(
                               "READY CHECK",
                               style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                             ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.amber),
                             
                             const SizedBox(height: 10),
                             Text(session.activityTitle, style: const TextStyle(color: Colors.white54, fontSize: 16)),
                             
                             const SizedBox(height: 40),
                             
                             // TIMER
                             Container(
                               width: 80, height: 80,
                               alignment: Alignment.center,
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 border: Border.all(color: _secondsRemaining < 10 ? Colors.red : Colors.greenAccent, width: 4)
                               ),
                               child: Text("$_secondsRemaining", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                             ),

                             const SizedBox(height: 40),

                             // PARTICIPANTS LIST
                             Expanded(
                               child: ListView.separated(
                                 padding: const EdgeInsets.symmetric(horizontal: 40),
                                 itemCount: participants.length,
                                 separatorBuilder: (_,__) => const SizedBox(height: 16),
                                 itemBuilder: (context, index) {
                                   final p = participants[index];
                                   final isReady = p.status == 'ready';
                                   final isDeclined = p.status == 'declined';
                                   
                                   return Row(
                                     children: [
                                       UserAvatar(photoUrl: p.photoUrl, radius: 24),
                                       const SizedBox(width: 16),
                                       Expanded(
                                         child: Text(p.displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                                       ),
                                       if (isReady) 
                                         const Icon(Icons.check_circle, color: Colors.greenAccent)
                                       else if (isDeclined)
                                         const Icon(Icons.cancel, color: Colors.redAccent)
                                       else 
                                         const SizedBox(
                                           width: 20, height: 20, 
                                           child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)
                                         )
                                     ],
                                   );
                                 },
                               ),
                             ),
                             
                             // ACTION BUTTONS
                             if (!_hasResponded) 
                               Padding(
                                 padding: const EdgeInsets.all(40),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     _ActionButton(
                                       color: Colors.redAccent, 
                                       icon: Icons.call_end, 
                                       label: "DECLINE",
                                       onTap: () {
                                          sessionService.setReadyStatus(widget.sessionId, 'declined');
                                          HapticFeedback.mediumImpact();
                                       },
                                     ),
                                     _ActionButton(
                                       color: Colors.greenAccent, 
                                       icon: Icons.check, 
                                       label: "READY",
                                       onTap: () {
                                          sessionService.setReadyStatus(widget.sessionId, 'ready');
                                          HapticFeedback.heavyImpact();
                                       },
                                     ),
                                   ],
                                 ),
                               )
                             else 
                               const Padding(
                                 padding: EdgeInsets.all(40),
                                 child: Text(
                                   "WAITING FOR SQUAD...", 
                                   style: TextStyle(color: Colors.white54, letterSpacing: 2)
                                 ),
                               )
                          ],
                        ),
                      )
                   ],
                 );
              }
            );
          },
        ),
      ),
    );
  }
}

// Result Animation Screen
class _ResultScreen extends StatelessWidget {
  final ReadyCheckResult result;
  const _ResultScreen({required this.result});

  @override
  Widget build(BuildContext context) {
    final isSuccess = result == ReadyCheckResult.success;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSuccess 
            ? [Colors.green.shade800, Colors.greenAccent, Colors.green.shade600]
            : [Colors.red.shade900, Colors.black, Colors.red.shade900],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSuccess ? Icons.celebration_rounded : Icons.cancel_rounded,
              size: 120,
              color: Colors.white,
            ).animate()
              .scale(duration: 500.ms, curve: Curves.elasticOut)
              .shake(duration: 500.ms, delay: 300.ms),
            const SizedBox(height: 24),
            Text(
              isSuccess ? "ALL READY!" : "SQUAD NOT READY",
              style: const TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                letterSpacing: 4
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0),
            const SizedBox(height: 8),
            Text(
              isSuccess ? "LET'S GO! 🔥" : "Maybe next time...",
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.color, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 70, height: 70,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
      ],
    );
  }
}
