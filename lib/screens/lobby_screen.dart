import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/lobby_model.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/services/lobby_service.dart';
import 'package:ready_check/services/sound_service.dart';
import 'package:ready_check/services/notification_service.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/widgets/chat_bottom_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LobbyScreen extends StatefulWidget {
  final String lobbyId;

  const LobbyScreen({super.key, required this.lobbyId});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _previousIsChecking = false;
  int _previousParticipantCount = 0;

  @override
  Widget build(BuildContext context) {
    final lobbyService = Provider.of<LobbyService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final soundService = Provider.of<SoundService>(context, listen: false);
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final currentUser = authService.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Squad Lobby"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ChatBottomSheet(lobbyId: widget.lobbyId),
          );
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: StreamBuilder<Lobby>(
        stream: lobbyService.streamLobby(widget.lobbyId),
        builder: (context, lobbySnapshot) {
          if (lobbySnapshot.hasError) {
            return Center(child: Text("Error: ${lobbySnapshot.error}"));
          }
          if (!lobbySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lobby = lobbySnapshot.data!;

          // Handle state transitions for Sound/Notifications
          if (lobby.isChecking && !_previousIsChecking) {
            soundService.playSummon();
            notificationService.showNotification(
              title: "READY CHECK!",
              body: "The host has requested a ready check. Are you ready?",
            );
            HapticFeedback.heavyImpact();
          }
          _previousIsChecking = lobby.isChecking;

          // Detect ALL READY
          return StreamBuilder<List<Participant>>(
             stream: lobbyService.streamParticipants(widget.lobbyId),
             builder: (context, participantsSnapshot) {
               if (!participantsSnapshot.hasData) return const Center(child: CircularProgressIndicator());
               
               final participants = participantsSnapshot.data!;
               final isEveryoneReady = participants.isNotEmpty && participants.every((p) => p.status == 'ready');
               
               return Stack(
                 children: [
                   Column(
                    children: [
                      _LobbyHeader(code: lobby.code),
                      Expanded(
                        child: _ParticipantGrid(
                          participants: participants, 
                          previousCount: _previousParticipantCount,
                          soundService: soundService,
                          onCountChanged: (c) => _previousParticipantCount = c,
                        ),
                      ),
                      if (!isEveryoneReady)
                        _LobbyFooter(
                          lobbyId: widget.lobbyId,
                          currentUserId: currentUser?.uid ?? '',
                          lobbyService: lobbyService,
                          isHost: lobby.hostId == currentUser?.uid,
                          isChecking: lobby.isChecking,
                        ),
                    ],
                   ),
                   if (isEveryoneReady)
                     _SuccessOverlay(
                       isHost: lobby.hostId == currentUser?.uid,
                       onReset: () {
                         lobbyService.cancelReadyCheck(widget.lobbyId);
                       },
                     ),
                 ],
               );
             }
          );
        },
      ),
    );
  }
}

class _LobbyHeader extends StatelessWidget {
  final String code;

  const _LobbyHeader({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Lobby Code",
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Text(
                code,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Code copied to clipboard")),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          )
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }
}

class _ParticipantCard extends StatelessWidget {
  final Participant participant;

  const _ParticipantCard({required this.participant});

  @override
  Widget build(BuildContext context) {
    final isReady = participant.status == 'ready';

    return AnimatedContainer(
      duration: 300.ms,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReady 
            ? const Color(0xFF4ADE80) 
            : Colors.transparent,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: isReady 
                ? const Color(0xFF4ADE80).withValues(alpha: 0.3) 
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              UserAvatar(
                photoUrl: participant.photoUrl,
                radius: 35,
              ),
              if (isReady)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ).animate().scale(curve: Curves.elasticOut),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            participant.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isReady ? const Color(0xFFDCFCE7) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isReady ? "READY" : "WAITING",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isReady ? const Color(0xFF166534) : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    ).animate(target: isReady ? 1 : 0).shimmer(duration: 1.seconds);
  }
}

class _LobbyFooter extends StatelessWidget {
  final String lobbyId;
  final String currentUserId;
  final LobbyService lobbyService;
  final bool isHost;
  final bool isChecking;

  const _LobbyFooter({
    required this.lobbyId,
    required this.currentUserId,
    required this.lobbyService,
    required this.isHost,
    required this.isChecking,
  });

  @override
  Widget build(BuildContext context) {
    if (isHost && !isChecking) {
      return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, -5),
                blurRadius: 20,
              )
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () async {
                   await lobbyService.startReadyCheck(lobbyId);
                   HapticFeedback.mediumImpact();
                },
                icon: const Icon(Icons.notifications_active),
                label: const Text(
                  "SUMMON SQUAD",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 5,
                ),
              ),
            ),
          ),
        );
    }
    
    if (!isChecking) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, -5),
                blurRadius: 20,
              )
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            child: Center(
              child: Text(
                "Waiting for Host to Summon...",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 16
                ),
              ),
            )
          ),
        );
    }

    return StreamBuilder<List<Participant>>(
      stream: lobbyService.streamParticipants(lobbyId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final me = snapshot.data!.firstWhere(
          (p) => p.uid == currentUserId,
          orElse: () => Participant(uid: '', displayName: '', photoUrl: ''),
        );
        
        final isReady = me.status == 'ready';

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, -5),
                blurRadius: 20,
              )
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea( 
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  lobbyService.setReadyStatus(
                    lobbyId, 
                    isReady ? 'waiting' : 'ready' 
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReady ? Colors.red.shade400 : const Color(0xFF4ADE80),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: isReady ? 0 : 5,
                ),
                child: Text(
                  isReady ? "CANCEL READY" : "I AM READY!",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ).animate(
                target: isReady ? 0 : 1, 
                onPlay: (controller) => controller.repeat(reverse: true),
              ).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1.seconds),
            ),
          ),
        );
      },
    );
  }
}

class _ParticipantGrid extends StatelessWidget {
  final List<Participant> participants;
  final int previousCount;
  final SoundService soundService;
  final ValueChanged<int> onCountChanged;

  const _ParticipantGrid({
    required this.participants,
    required this.previousCount,
    required this.soundService,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Participant>.from(participants);
    sorted.sort((a, b) {
      if (a.status == 'ready' && b.status != 'ready') return -1;
      if (a.status != 'ready' && b.status == 'ready') return 1;
      return a.displayName.compareTo(b.displayName);
    });

    if (participants.length != previousCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (participants.length > previousCount && previousCount != 0) {
              soundService.playJoin();
          }
          onCountChanged(participants.length);
        });
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return _ParticipantCard(participant: sorted[index]);
      },
    );
  }
}

class _SuccessOverlay extends StatelessWidget {
  final bool isHost;
  final VoidCallback onReset;

  const _SuccessOverlay({required this.isHost, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8), 
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF4ADE80), size: 100)
              .animate()
              .scale(duration: 500.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 2.seconds, delay: 500.ms),
          const SizedBox(height: 24),
          const Text(
            "MATCH FOUND!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ).animate().fadeIn().moveY(begin: 20, end: 0, delay: 200.ms),
          const SizedBox(height: 8),
          const Text(
            "Everyone is ready to go.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 48),
          if (isHost)
            ElevatedButton(
              onPressed: onReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("RESET LOBBY"),
            ).animate().fadeIn(delay: 1.seconds).scale(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
