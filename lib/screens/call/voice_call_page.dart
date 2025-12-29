import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/call_model.dart';
import 'package:ready_check/services/call_service.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';

class VoiceCallPage extends StatefulWidget {
  final String callId;
  final bool isOutgoing;
  final String? otherUserName;
  final String? otherUserPhoto;
  final bool isGroupCall;
  final String? circleName;

  const VoiceCallPage({
    super.key,
    required this.callId,
    this.isOutgoing = false,
    this.otherUserName,
    this.otherUserPhoto,
    this.isGroupCall = false,
    this.circleName,
  });

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _callDuration = 0;
  bool _isConnected = false;
  bool _hasPopped = false; // Prevent double pop
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _safelyPop() {
    if (!_hasPopped && mounted && Navigator.of(context).canPop()) {
      _hasPopped = true;
      Navigator.of(context).pop();
    }
  }

  void _endCall() {
    final callService = Provider.of<CallService>(context, listen: false);
    callService.endCall();
    _safelyPop();
  }

  @override
  Widget build(BuildContext context) {
    final callService = Provider.of<CallService>(context);

    return StreamBuilder<Call?>(
      stream: callService.streamCall(widget.callId),
      builder: (context, snapshot) {
        final call = snapshot.data;
        
        // Check if call ended
        if (call?.status == CallStatus.ended || call?.status == CallStatus.declined) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _safelyPop();
          });
        }

        // Check if connected
        if (call?.status == CallStatus.ongoing && !_isConnected) {
          _isConnected = true;
          _startTimer();
          HapticFeedback.mediumImpact();
        }

        return Scaffold(
          backgroundColor: const Color(0xFF1A1A2E),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // User Avatar with pulse animation
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.1);
                    return Transform.scale(
                      scale: _isConnected ? 1.0 : scale,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isConnected ? Colors.greenAccent : Colors.blueAccent.withOpacity(0.5),
                            width: 3,
                          ),
                        ),
                        child: UserAvatar(
                          photoUrl: widget.otherUserPhoto ?? '',
                          radius: 60,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // User name
                Text(
                  widget.isGroupCall 
                      ? (widget.circleName ?? 'Group Call')
                      : (widget.otherUserName ?? 'Unknown'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Status / Duration
                Text(
                  _isConnected 
                      ? _formatDuration(_callDuration)
                      : (widget.isOutgoing ? 'Calling...' : 'Incoming call'),
                  style: TextStyle(
                    color: _isConnected ? Colors.greenAccent : Colors.white54,
                    fontSize: 16,
                  ),
                ),

                const Spacer(),

                // Connected users count (for group calls)
                if (widget.isGroupCall && _isConnected)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${callService.remoteUsers.length + 1} connected',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // Control buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute button
                      _CallButton(
                        icon: callService.isMuted ? Icons.mic_off : Icons.mic,
                        label: callService.isMuted ? 'Unmute' : 'Mute',
                        color: callService.isMuted ? Colors.redAccent : Colors.white24,
                        onTap: () => callService.toggleMute(),
                      ),
                      
                      // End call button
                      _CallButton(
                        icon: Icons.call_end,
                        label: 'End',
                        color: Colors.redAccent,
                        size: 70,
                        onTap: _endCall,
                      ),
                      
                      // Speaker button
                      _CallButton(
                        icon: callService.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        label: 'Speaker',
                        color: callService.isSpeakerOn ? Colors.blueAccent : Colors.white24,
                        onTap: () => callService.toggleSpeaker(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
