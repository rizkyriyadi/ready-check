import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/friend_model.dart';
import 'package:ready_check/services/friend_service.dart';
import 'package:ready_check/services/direct_chat_service.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/chat/direct_chat_page.dart';
import 'package:intl/intl.dart';

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
  int _friendCount = 0;

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
    final currentUser = Provider.of<AuthService>(context).user;
    final isOwnProfile = currentUser?.uid == widget.userId;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 80, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              const Text('User not found', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                'ID: ${widget.userId}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isOwnProfile && _friendshipStatus == 'friend')
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptionsMenu(context),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Avatar & Name
                UserAvatar(photoUrl: _user!.photoUrl, radius: 60),
                const SizedBox(height: 16),
                Text(
                  _user!.displayName.isEmpty ? 'Anonymous' : _user!.displayName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Status badge
                if (!isOwnProfile)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor().withOpacity(0.5)),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(color: _getStatusColor(), fontSize: 12),
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // User ID card
                GlassContainer(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  opacity: 0.2,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fingerprint, color: Colors.grey.shade500, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'User ID',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _user!.uid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID Copied!')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _user!.uid,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.copy, size: 14, color: Colors.grey.shade500),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                if (!isOwnProfile)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _buildPrimaryAction(context),
                        const SizedBox(height: 12),
                        if (_friendshipStatus == 'friend')
                          _buildMessageButton(context),
                      ],
                    ),
                  ),
                  
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_friendshipStatus) {
      case 'friend': return Colors.greenAccent;
      case 'pending': return Colors.orangeAccent;
      case 'incoming': return Colors.blueAccent;
      default: return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_friendshipStatus) {
      case 'friend': return '✓ Friends';
      case 'pending': return '⏳ Request Sent';
      case 'incoming': return '📨 Wants to be friends';
      default: return 'Not Friends';
    }
  }

  Widget _buildPrimaryAction(BuildContext context) {
    final friendService = Provider.of<FriendService>(context, listen: false);

    switch (_friendshipStatus) {
      case 'friend':
        return const SizedBox.shrink(); // Actions in menu
      
      case 'pending':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.hourglass_empty),
            label: const Text('Request Pending'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await friendService.acceptFriendRequest(widget.userId);
                  if (mounted) {
                    setState(() => _friendshipStatus = 'friend');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_user!.displayName} is now your friend!')),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );
    }
  }

  Widget _buildMessageButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          debugPrint('DM Button pressed for user: ${widget.userId}');
          try {
            final chatService = Provider.of<DirectChatService>(context, listen: false);
            debugPrint('Getting/creating chat...');
            final chatId = await chatService.getOrCreateChat(widget.userId);
            debugPrint('Chat ID: $chatId');
            
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
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not create chat. Please try again.')),
                );
              }
            }
          } catch (e) {
            debugPrint('DM Button error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
        icon: const Icon(Icons.message),
        label: const Text('Send Message'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white30),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final friendService = Provider.of<FriendService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.redAccent),
              title: const Text('Remove Friend', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Remove Friend'),
                    content: Text('Remove ${_user!.displayName} from your friends?'),
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
                if (confirm == true && mounted) {
                  await friendService.removeFriend(widget.userId);
                  setState(() => _friendshipStatus = 'none');
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
