import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/call_model.dart';
import 'package:ready_check/services/call_service.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/call/voice_call_page.dart';
import 'package:audioplayers/audioplayers.dart';

class IncomingCallOverlay extends StatefulWidget {
  final Call call;

  const IncomingCallOverlay({super.key, required this.call});

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAnswering = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Vibrate and play ringtone
    _startRinging();
  }

  void _startRinging() async {
    HapticFeedback.heavyImpact();
    
    // Play ringtone (using system sound for now)
    try {
      if (_audioPlayer.state != PlayerState.playing) {
         await _audioPlayer.setReleaseMode(ReleaseMode.loop);
         // Try to load asset, but don't crash if missing
         await _audioPlayer.play(AssetSource('sounds/ringtone.mp3')).catchError((e) {
            debugPrint('Ringtone asset missing or error: $e');
         });
      }
    } catch (e) {
      debugPrint('Could not play ringtone: $e');
    }

    // Vibrate pattern indefinitely until stopped
    _vibrateLoop();
  }

  void _vibrateLoop() async {
    while (mounted && !_isAnswering) {
      if (mounted) HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _acceptCall() async {
    if (_isAnswering) return;
    setState(() => _isAnswering = true);
    
    _audioPlayer.stop();
    
    final callService = Provider.of<CallService>(context, listen: false);
    final success = await callService.joinCall(widget.call.id);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VoiceCallPage(
            callId: widget.call.id,
            isOutgoing: false,
            otherUserName: widget.call.callerName,
            otherUserPhoto: widget.call.callerPhoto,
            isGroupCall: widget.call.isGroupCall,
          ),
        ),
      );
    }
  }

  void _declineCall() async {
    _audioPlayer.stop();
    
    final callService = Provider.of<CallService>(context, listen: false);
    await callService.declineCall(widget.call.id);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Caller info
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.6),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: UserAvatar(
                      photoUrl: widget.call.callerPhoto,
                      radius: 70,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Caller name
            Text(
              widget.call.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Call type
            Text(
              widget.call.isGroupCall ? 'Group Voice Call' : 'Voice Call',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 16,
              ),
            ),

            const Spacer(),

            // Accept/Decline buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: 'Decline',
                    color: Colors.redAccent,
                    onTap: _declineCall,
                  ),

                  // Accept
                  _CallActionButton(
                    icon: Icons.call,
                    label: 'Accept',
                    color: Colors.greenAccent,
                    onTap: _acceptCall,
                    isLoading: _isAnswering,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isLoading ? null : onTap,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
