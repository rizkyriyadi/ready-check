import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/friend_model.dart';
import 'package:ready_check/services/friend_service.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';

class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final friendService = Provider.of<FriendService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<FriendRequest>>(
        stream: friendService.streamFriendRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'No friend requests',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  opacity: 0.2,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      UserAvatar(photoUrl: request.fromPhoto, radius: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.fromName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            Text(
                              'Wants to be your friend',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => friendService.rejectFriendRequest(request.fromUid),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.greenAccent),
                        onPressed: () async {
                          final success = await friendService.acceptFriendRequest(request.fromUid);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${request.fromName} is now your friend!')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
