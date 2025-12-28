import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:ready_check/models/circle_model.dart';
import 'package:ready_check/services/circle_service.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/services/session_service.dart';
import 'package:ready_check/screens/session/ready_check_overlay.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:intl/intl.dart';

class CircleDetailPage extends StatefulWidget {
  final String circleId;
  final String circleName;

  const CircleDetailPage({super.key, required this.circleId, required this.circleName});

  @override
  State<CircleDetailPage> createState() => _CircleDetailPageState();
}

class _CircleDetailPageState extends State<CircleDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    final bs = Provider.of<CircleService>(context, listen: false);
    bs.sendCircleMessage(widget.circleId, _messageController.text);
    _messageController.clear();
    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _triggerSummon() async {
     final sessionService = Provider.of<SessionService>(context, listen: false);
     final sessionId = await sessionService.createSession(
       circleId: widget.circleId,
       activityTitle: "${widget.circleName} Raid",
       requiredSlots: 5,
       isPublic: true
     );
     
     if (sessionId != null && mounted) {
        // Creator navigates directly to the overlay
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReadyCheckOverlay(sessionId: sessionId))
        );
        final bs = Provider.of<CircleService>(context, listen: false);
        bs.sendCircleMessage(widget.circleId, "SUMMONED THE SQUAD! JOIN NOW!");
     }
  }
  
  void _showInviteCode(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(widget.circleName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Invite Code:"),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text("Share this code with friends.", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Close"))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleService = Provider.of<CircleService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.user?.uid;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true, // For glass effect
      appBar: AppBar(
        title: Text(widget.circleName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        flexibleSpace: GlassContainer(
          borderRadius: BorderRadius.zero,
          blur: 10, 
          opacity: 0.2, // Subtle glass
          child: Container(),
        ),
        actions: [
          // Summon Action
          IconButton(
            onPressed: _triggerSummon,
            icon: const Icon(Icons.bolt, color: Colors.amberAccent),
            tooltip: "Summon Squad",
          ),
          // Invite Info Action
          StreamBuilder<Circle>(
            stream: circleService.streamCircle(widget.circleId),
            builder: (context, snapshot) {
              final code = snapshot.data?.code ?? '...';
              return IconButton(
                icon: const Icon(Icons.info_outline), 
                onPressed: () => _showInviteCode(code),
              );
            }
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // Subtle gradient background
           gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.brightness == Brightness.dark 
                 ? [const Color(0xFF111827), const Color(0xFF1F2937)]
                 : [const Color(0xFFF9FAFB), const Color(0xFFF3F4F6)]
           )
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: circleService.streamCircleMessages(widget.circleId),
                builder: (context, snapshot) {
                   if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                   final messages = snapshot.data!;
                   if (messages.isEmpty) return Center(child: Text("Say hi to the squad!", style: TextStyle(color: theme.hintColor)));
  
                   return ListView.builder(
                     controller: _scrollController,
                     reverse: true,
                     padding: const EdgeInsets.fromLTRB(16, 120, 16, 20), // Top padding for glass AppBar
                     itemCount: messages.length,
                     itemBuilder: (context, index) {
                       final msg = messages[index];
                       final isMe = msg.senderId == currentUserId;
                       return _CircleMessageBubble(message: msg, isMe: isMe);
                     },
                   );
                },
              ),
            ),
            
            // Input Area - Glass & Dark Mode Ready
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GlassContainer(
                  blur: 10,
                  opacity: theme.brightness == Brightness.dark ? 0.3 : 0.6,
                  color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                            decoration: InputDecoration(
                              hintText: "Message...",
                              hintStyle: TextStyle(color: theme.hintColor),
                              border: InputBorder.none,
                              filled: false,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        IconButton(
                          onPressed: _sendMessage, 
                          icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _CircleMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _CircleMessageBubble({required this.message, required this.isMe});
  
  void _showUserProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        opacity: 0.9,
        color: Theme.of(context).canvasColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             UserAvatar(photoUrl: message.senderPhotoUrl, radius: 40),
             const SizedBox(height: 16),
             Text(message.senderName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
             SelectableText("ID: ${message.senderId}", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
             const SizedBox(height: 24),
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // System Message Check
    if (message.text.contains("SUMMONED THE SQUAD")) {
       return Center(
         child: Container(
           margin: const EdgeInsets.symmetric(vertical: 12),
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           decoration: BoxDecoration(
             color: Colors.amber.withValues(alpha: 0.1), 
             borderRadius: BorderRadius.circular(16), 
             border: Border.all(color: Colors.amber)
           ),
           child: Text("⚡ ${message.senderName} SUMMONED THE SQUAD!", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
         ),
       );
    }

    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => _showUserProfile(context),
              child: UserAvatar(photoUrl: message.senderPhotoUrl, radius: 16),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                 if (!isMe) ...[
                   GestureDetector(
                     onTap: () => _showUserProfile(context),
                     child: Padding(
                       padding: const EdgeInsets.only(bottom: 4, left: 4),
                       child: Text(message.senderName, style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                     ),
                   )
                 ],
                 Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? theme.colorScheme.primary.withValues(alpha: 0.2) : theme.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: !isMe ? const Radius.circular(20) : const Radius.circular(4),
                    ),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                       Text(message.text, style: TextStyle(fontSize: 15, color: theme.textTheme.bodyLarge?.color)),
                       const SizedBox(height: 4),
                       Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Text(timeStr, style: TextStyle(fontSize: 9, color: theme.textTheme.bodySmall?.color)),
                           if (isMe) ...[
                             const SizedBox(width: 4),
                             Icon(
                                message.status == MessageStatus.read ? Icons.done_all : Icons.check, 
                                size: 12, 
                                color: message.status == MessageStatus.read ? Colors.blue : Colors.grey
                             )
                           ]
                         ],
                       )
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (isMe) const SizedBox(width: 48),
        ],
      ),
    );
  }
}
