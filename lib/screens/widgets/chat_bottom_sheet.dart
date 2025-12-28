import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:ready_check/services/lobby_service.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class ChatBottomSheet extends StatefulWidget {
  final String lobbyId;

  const ChatBottomSheet({super.key, required this.lobbyId});

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    
    final lobbyService = Provider.of<LobbyService>(context, listen: false);
    lobbyService.sendMessage(widget.lobbyId, _controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.user?.uid;
    final lobbyService = Provider.of<LobbyService>(context, listen: false);

    return Container(
       height: MediaQuery.of(context).size.height * 0.75,
       decoration: const BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
       ),
       child: Column(
         children: [
           // Header
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
             decoration: BoxDecoration(
               border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
             ),
             child: Row(
               children: [
                 const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blueAccent),
                 const SizedBox(width: 12),
                 const Text("Squad Chat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 const Spacer(),
                 IconButton(
                   icon: const Icon(Icons.close),
                   onPressed: () => Navigator.pop(context),
                 )
               ],
             ),
           ),
           
           // Messages List
           Expanded(
             child: StreamBuilder<List<Message>>(
               stream: lobbyService.streamMessages(widget.lobbyId),
               builder: (context, snapshot) {
                 if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                 final messages = snapshot.data!;
                 if (messages.isEmpty) {
                   return Center(
                     child: Text("No messages yet.\nSay hello!", 
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey.shade400),
                     ),
                   );
                 }

                 return ListView.builder(
                   reverse: true, // Show newest at bottom (requires logic adjustment if stream is desc)
                   // actually stream is desc timestamp, so index 0 is newest. reverse: true puts index 0 at bottom. Correct.
                   padding: const EdgeInsets.all(16),
                   itemCount: messages.length,
                   itemBuilder: (context, index) {
                     final msg = messages[index];
                     final isMe = msg.senderId == currentUserId;
                     return _MessageBubble(message: msg, isMe: isMe);
                   },
                 );
               },
             ),
           ),
           
           // Input Area
           Padding(
             padding: EdgeInsets.only(
               left: 16, 
               right: 16, 
               top: 16, 
               bottom: 16 + MediaQuery.of(context).viewInsets.bottom
             ),
             child: Row(
               children: [
                 Expanded(
                   child: TextField(
                     controller: _controller,
                     decoration: InputDecoration(
                       hintText: "Type a message...",
                       filled: true,
                       fillColor: Colors.grey.shade100,
                       border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(30),
                         borderSide: BorderSide.none,
                       ),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                     ),
                     onSubmitted: (_) => _sendMessage(),
                     textInputAction: TextInputAction.send,
                   ),
                 ),
                 const SizedBox(width: 8),
                 IconButton.filled(
                   onPressed: _sendMessage,
                   icon: const Icon(Icons.send_rounded),
                   style: IconButton.styleFrom(
                     backgroundColor: Theme.of(context).colorScheme.primary,
                   ),
                 )
               ],
             ),
           )
         ],
       ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  message.senderName, 
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF6366F1).withValues(alpha: 0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: !isMe ? const Radius.circular(16) : Radius.zero,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(message.text, style: const TextStyle(fontSize: 15)),
                   const SizedBox(height: 2),
                   Text(timeStr, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0, duration: 200.ms);
  }
}
