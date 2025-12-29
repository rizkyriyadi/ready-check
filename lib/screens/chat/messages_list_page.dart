import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/friend_model.dart';
import 'package:ready_check/services/direct_chat_service.dart';
import 'package:ready_check/screens/chat/direct_chat_page.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:intl/intl.dart';

class MessagesListPage extends StatelessWidget {
  const MessagesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<DirectChatService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<DirectChat>>(
        stream: chatService.streamUserChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a chat from a friend\'s profile',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListTile(chat: chat);
            },
          );
        },
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final DirectChat chat;

  const _ChatListTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat.jm();
    final dateFormat = DateFormat.MMMd();
    final now = DateTime.now();
    final isToday = chat.lastMessageAt.day == now.day &&
        chat.lastMessageAt.month == now.month &&
        chat.lastMessageAt.year == now.year;

    return ListTile(
      leading: Stack(
        children: [
          UserAvatar(photoUrl: chat.otherUserPhoto, radius: 28),
          if (chat.unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  chat.unreadCount > 9 ? '9+' : chat.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        chat.otherUserName,
        style: TextStyle(
          fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        chat.lastMessage.isEmpty ? 'No messages yet' : chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: chat.unreadCount > 0 ? Colors.white70 : Colors.grey.shade500,
          fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Text(
        isToday ? timeFormat.format(chat.lastMessageAt) : dateFormat.format(chat.lastMessageAt),
        style: TextStyle(
          fontSize: 12,
          color: chat.unreadCount > 0 ? Colors.greenAccent : Colors.grey.shade600,
        ),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DirectChatPage(
              chatId: chat.id,
              otherUserName: chat.otherUserName,
              otherUserPhoto: chat.otherUserPhoto,
              otherUserId: chat.otherUserId,
            ),
          ),
        );
      },
    );
  }
}
