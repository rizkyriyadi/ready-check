import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ready_check/models/circle_model.dart';
import 'package:ready_check/models/friend_model.dart';
import 'package:ready_check/services/circle_service.dart';
import 'package:ready_check/services/friend_service.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';

class CircleSettingsPage extends StatefulWidget {
  final String circleId;

  const CircleSettingsPage({super.key, required this.circleId});

  @override
  State<CircleSettingsPage> createState() => _CircleSettingsPageState();
}

class _CircleSettingsPageState extends State<CircleSettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final circleService = Provider.of<CircleService>(context, listen: false);
    final members = await circleService.getCircleMembers(widget.circleId);
    if (mounted) {
      setState(() => _members = members);
    }
  }

  Future<void> _updateName(String currentName) async {
    _nameController.text = currentName;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Circle Name'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      setState(() => _isLoading = true);
      final circleService = Provider.of<CircleService>(context, listen: false);
      await circleService.updateCircleName(widget.circleId, result.trim());
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Circle name updated!')),
        );
      }
    }
  }

  Future<void> _updatePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
    );

    if (image != null && mounted) {
      setState(() => _isLoading = true);
      final circleService = Provider.of<CircleService>(context, listen: false);
      final success = await circleService.updateCirclePhoto(widget.circleId, File(image.path));
      setState(() => _isLoading = false);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Circle photo updated!')),
        );
      }
    }
  }

  Future<void> _leaveCircle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Circle?'),
        content: const Text('You will no longer receive messages from this circle.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final circleService = Provider.of<CircleService>(context, listen: false);
      final success = await circleService.leaveCircle(widget.circleId);
      setState(() => _isLoading = false);
      if (success && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You left the circle')),
        );
      }
    }
  }

  Future<void> _addFromFriends() async {
    final friendService = Provider.of<FriendService>(context, listen: false);
    final circleService = Provider.of<CircleService>(context, listen: false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add Friends to Circle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<List<Friend>>(
                stream: friendService.streamFriends(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final friends = snapshot.data!;
                  final memberIds = _members.map((m) => m['uid'] as String).toSet();
                  final availableFriends = friends.where((f) => !memberIds.contains(f.uid)).toList();

                  if (availableFriends.isEmpty) {
                    return Center(
                      child: Text(
                        'All your friends are already in this circle!',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: availableFriends.length,
                    itemBuilder: (context, index) {
                      final friend = availableFriends[index];
                      return ListTile(
                        leading: UserAvatar(photoUrl: friend.photoUrl, radius: 24),
                        title: Text(friend.displayName),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                          onPressed: () async {
                            final success = await circleService.addMember(widget.circleId, friend.uid);
                            if (success && mounted) {
                              await _loadMembers();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${friend.displayName} added!')),
                              );
                              Navigator.pop(ctx);
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleService = Provider.of<CircleService>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Circle Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Circle>(
              stream: circleService.streamCircle(widget.circleId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final circle = snapshot.data!;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Circle Photo
                    Center(
                      child: GestureDetector(
                        onTap: _updatePhoto,
                        child: Stack(
                          children: [
                            circle.photoUrl.isNotEmpty
                                ? CircleAvatar(
                                    radius: 50,
                                    backgroundImage: NetworkImage(circle.photoUrl),
                                  )
                                : CircleAvatar(
                                    radius: 50,
                                    backgroundColor: theme.colorScheme.primary.withOpacity(0.3),
                                    child: const Icon(Icons.group, size: 40),
                                  ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Circle Name
                    GlassContainer(
                      opacity: 0.1,
                      child: ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Circle Name'),
                        subtitle: Text(circle.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _updateName(circle.name),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Invite Code
                    GlassContainer(
                      opacity: 0.1,
                      child: ListTile(
                        leading: const Icon(Icons.link),
                        title: const Text('Invite Code'),
                        subtitle: Text(circle.code, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Members Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Members (${_members.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _addFromFriends,
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._members.map((member) => ListTile(
                      leading: UserAvatar(photoUrl: member['photoUrl'] ?? '', radius: 20),
                      title: Text(member['displayName'] ?? 'Unknown'),
                      contentPadding: EdgeInsets.zero,
                    )),
                    const SizedBox(height: 32),

                    // Leave Circle
                    OutlinedButton.icon(
                      onPressed: _leaveCircle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Leave Circle'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
