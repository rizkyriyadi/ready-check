import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/friend_model.dart';
import 'package:ready_check/services/friend_service.dart';
import 'package:ready_check/services/direct_chat_service.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/chat/direct_chat_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  AppUser? _user;
  String _friendshipStatus = 'loading';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final friendService = Provider.of<FriendService>(context, listen: false);
    
    final user = await friendService.getUserById(widget.userId);
    final status = await friendService.getFriendshipStatus(widget.userId);
    
    if (mounted) {
      setState(() {
        _user = user;
        _friendshipStatus = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile Card
                GlassContainer(
                  padding: const EdgeInsets.all(24),
                  opacity: 0.3,
                  child: Column(
                    children: [
                      UserAvatar(photoUrl: _user!.photoUrl, radius: 60),
                      const SizedBox(height: 16),
                      Text(
                        _user!.displayName.isEmpty ? 'Anonymous' : _user!.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _user!.uid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID Copied!')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ID: ${_user!.uid.substring(0, 8)}...',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.copy, size: 12, color: Colors.grey.shade500),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  opacity: 0.2,
                  child: Column(
                    children: [
                      _buildActionButton(context),
                      if (_friendshipStatus == 'friend') ...[
                        const SizedBox(height: 12),
                        _buildMessageButton(context),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final friendService = Provider.of<FriendService>(context, listen: false);

    switch (_friendshipStatus) {
      case 'self':
        return const SizedBox.shrink();
      
      case 'friend':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Remove Friend'),
                  content: Text('Remove ${_user!.displayName} from friends?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await friendService.removeFriend(widget.userId);
                if (mounted) {
                  setState(() => _friendshipStatus = 'none');
                }
              }
            },
            icon: const Icon(Icons.person_remove, color: Colors.redAccent),
            label: const Text('Remove Friend', style: TextStyle(color: Colors.redAccent)),
          ),
        );

      case 'pending':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_empty),
            label: const Text('Request Sent'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.grey,
            ),
          ),
        );

      case 'incoming':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await friendService.rejectFriendRequest(widget.userId);
                  if (mounted) setState(() => _friendshipStatus = 'none');
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await friendService.acceptFriendRequest(widget.userId);
                  if (mounted) {
                    setState(() => _friendshipStatus = 'friend');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_user!.displayName} is now your friend!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                child: const Text('Accept'),
              ),
            ),
          ],
        );

      default: // 'none'
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final success = await friendService.sendFriendRequest(widget.userId);
              if (success && mounted) {
                setState(() => _friendshipStatus = 'pending');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Friend request sent!')),
                );
              }
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Add Friend'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
          ),
        );
    }
  }

  Widget _buildMessageButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final chatService = Provider.of<DirectChatService>(context, listen: false);
          final chatId = await chatService.getOrCreateChat(widget.userId);
          
          if (chatId != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DirectChatPage(
                  chatId: chatId,
                  otherUserName: _user!.displayName,
                  otherUserPhoto: _user!.photoUrl,
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.message),
        label: const Text('Send Message'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
