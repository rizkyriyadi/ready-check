import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/friend_model.dart';
import 'package:ready_check/services/friend_service.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/friends/friend_list_page.dart';
import 'package:ready_check/screens/friends/friend_requests_page.dart';
import 'package:ready_check/screens/friends/user_profile_page.dart';

class FriendsHubPage extends StatelessWidget {
  const FriendsHubPage({super.key});

  void _addFriendById(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Friend by ID"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Paste friend's User ID",
            prefixIcon: Icon(Icons.person_search),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => UserProfilePage(userId: controller.text.trim())),
                );
              }
            },
            child: const Text("Find"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendService = Provider.of<FriendService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Friend',
            onPressed: () => _addFriendById(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Friend Requests Section
            StreamBuilder<List<FriendRequest>>(
              stream: friendService.streamFriendRequests(),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? [];
                if (requests.isEmpty) return const SizedBox.shrink();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.person_add, color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Friend Requests (${requests.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...requests.take(3).map((request) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassContainer(
                        opacity: 0.2,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            UserAvatar(photoUrl: request.fromPhoto, radius: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.fromName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Wants to be friends',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                              onPressed: () => friendService.rejectFriendRequest(request.fromUid),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.greenAccent, size: 20),
                              onPressed: () async {
                                final success = await friendService.acceptFriendRequest(request.fromUid);
                                if (success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${request.fromName} added!')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    )),
                    if (requests.length > 3)
                      TextButton(
                        onPressed: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const FriendRequestsPage())
                        ),
                        child: Text('See all ${requests.length} requests'),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Friends List Section
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  StreamBuilder<List<Friend>>(
                    stream: friendService.streamFriends(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Text(
                        'My Friends ($count)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            StreamBuilder<List<Friend>>(
              stream: friendService.streamFriends(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friends = snapshot.data ?? [];

                if (friends.isEmpty) {
                  return GlassContainer(
                    opacity: 0.15,
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 60, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        Text(
                          'No friends yet',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _addFriendById(context),
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Add by ID'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: friends.map((friend) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassContainer(
                      opacity: 0.15,
                      child: ListTile(
                        leading: UserAvatar(photoUrl: friend.photoUrl, radius: 22),
                        title: Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => UserProfilePage(userId: friend.uid)),
                        ),
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
