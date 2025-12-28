import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:ready_check/services/direct_chat_service.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DirectChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserPhoto;

  const DirectChatPage({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserPhoto,
  });

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<DirectChatService>(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            UserAvatar(photoUrl: widget.otherUserPhoto, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: chatService.streamMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hi! 👋',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUid;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            UserAvatar(photoUrl: msg.senderPhotoUrl, radius: 14),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe 
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                  color: isMe ? Colors.greenAccent.shade100 : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          if (isMe) const SizedBox(width: 8),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input
          GlassContainer(
            opacity: 0.3,
            borderRadius: BorderRadius.zero,
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(chatService),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent),
                  onPressed: () => _sendMessage(chatService),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(DirectChatService service) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    await service.sendMessage(widget.chatId, text);
  }
}
