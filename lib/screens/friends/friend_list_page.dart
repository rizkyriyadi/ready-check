import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/friend_model.dart';
import 'package:ready_check/services/friend_service.dart';
import 'package:ready_check/services/direct_chat_service.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/chat/direct_chat_page.dart';

class FriendListPage extends StatelessWidget {
  const FriendListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final friendService = Provider.of<FriendService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Friend>>(
        stream: friendService.streamFriends(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final friends = snapshot.data ?? [];

          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'No friends yet',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add friends from their profile',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  opacity: 0.2,
                  child: ListTile(
                    leading: UserAvatar(photoUrl: friend.photoUrl, radius: 24),
                    title: Text(
                      friend.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.greenAccent),
                          onPressed: () => _openChat(context, friend),
                        ),
                        IconButton(
                          icon: Icon(Icons.person_remove, color: Colors.red.shade300),
                          onPressed: () => _confirmRemove(context, friendService, friend),
                        ),
                      ],
                    ),
                    onTap: () => _openChat(context, friend),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openChat(BuildContext context, Friend friend) async {
    final chatService = Provider.of<DirectChatService>(context, listen: false);
    final chatId = await chatService.getOrCreateChat(friend.uid);
    
    if (chatId != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DirectChatPage(
            chatId: chatId,
            otherUserName: friend.displayName,
            otherUserPhoto: friend.photoUrl,
            otherUserId: friend.uid,
          ),
        ),
      );
    }
  }

  void _confirmRemove(BuildContext context, FriendService service, Friend friend) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${friend.displayName} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await service.removeFriend(friend.uid);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
