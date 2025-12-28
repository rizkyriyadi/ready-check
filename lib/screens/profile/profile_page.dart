import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ready_check/models/friend_model.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/services/theme_service.dart';
import 'package:ready_check/services/friend_service.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/onboarding_screen.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/friends/friends_hub_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null && context.mounted) {
      final auth = Provider.of<AuthService>(context, listen: false);
      try {
        await auth.updateProfilePhoto(File(pickedFile.path));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo Updated!")));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _editName(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new name"),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                 final auth = Provider.of<AuthService>(context, listen: false);
                 await auth.updateDisplayName(controller.text);
                 if (context.mounted) Navigator.pop(context);
              }
            }, 
            child: const Text("Save")
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final friendService = Provider.of<FriendService>(context);
    final user = authService.user;

    if (user == null) return const SizedBox();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themeService.isDarkMode 
               ? [const Color(0xFF1F2937), const Color(0xFF111827)]
               : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)]
          )
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile Card
                GlassContainer(
                   padding: const EdgeInsets.all(24),
                   opacity: themeService.isDarkMode ? 0.3 : 0.6,
                   child: Column(
                     children: [
                       Stack(
                         children: [
                           UserAvatar(photoUrl: user.photoURL, radius: 60),
                           Positioned(
                             bottom: 0, right: 0,
                             child: GestureDetector(
                               onTap: () => _pickImage(context),
                               child: CircleAvatar(
                                 radius: 18,
                                 backgroundColor: Theme.of(context).colorScheme.primary,
                                 child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                               ),
                             ),
                           )
                         ],
                       ),
                       const SizedBox(height: 16),
                       GestureDetector(
                         onTap: () => _editName(context, user.displayName ?? ""),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Text(
                               user.displayName ?? "No Name",
                               style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                             ),
                             const SizedBox(width: 8),
                             Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.primary)
                           ],
                         ),
                       ),
                       const SizedBox(height: 8),
                       InkWell(
                         onTap: () {
                           Clipboard.setData(ClipboardData(text: user.uid));
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Copied!")));
                         },
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                             borderRadius: BorderRadius.circular(20)
                           ),
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Text("ID: ${user.uid.substring(0,6)}...", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                               const SizedBox(width: 4),
                               const Icon(Icons.copy, size: 12, color: Colors.grey)
                             ],
                           ),
                         ),
                       ),
                       const SizedBox(height: 20),
                       // Friends Button - Clean single entry
                       StreamBuilder<List<Friend>>(
                         stream: friendService.streamFriends(),
                         builder: (context, friendSnap) {
                           return StreamBuilder<List<FriendRequest>>(
                             stream: friendService.streamFriendRequests(),
                             builder: (context, requestSnap) {
                               final friendCount = friendSnap.data?.length ?? 0;
                               final requestCount = requestSnap.data?.length ?? 0;
                               
                               return InkWell(
                                 onTap: () => Navigator.push(
                                   context, 
                                   MaterialPageRoute(builder: (_) => const FriendsHubPage())
                                 ),
                                 borderRadius: BorderRadius.circular(12),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                   decoration: BoxDecoration(
                                     color: Colors.greenAccent.withOpacity(0.2),
                                     borderRadius: BorderRadius.circular(12),
                                     border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                                   ),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       const Icon(Icons.people, color: Colors.greenAccent),
                                       const SizedBox(width: 10),
                                       Text(
                                         '$friendCount Friends',
                                         style: const TextStyle(fontWeight: FontWeight.w600),
                                       ),
                                       if (requestCount > 0) ...[
                                         const SizedBox(width: 10),
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                           decoration: BoxDecoration(
                                             color: Colors.orangeAccent,
                                             borderRadius: BorderRadius.circular(12),
                                           ),
                                           child: Text(
                                             '+$requestCount',
                                             style: const TextStyle(
                                               color: Colors.white, 
                                               fontSize: 12, 
                                               fontWeight: FontWeight.bold
                                             ),
                                           ),
                                         ),
                                       ],
                                       const SizedBox(width: 8),
                                       const Icon(Icons.arrow_forward_ios, size: 14),
                                     ],
                                   ),
                                 ),
                               );
                             },
                           );
                         },
                       ),
                     ],
                   ),
                ),
                
                const SizedBox(height: 24),
                
                // Settings Card - Clean, minimal
                GlassContainer(
                   padding: const EdgeInsets.symmetric(vertical: 8),
                   opacity: themeService.isDarkMode ? 0.2 : 0.5,
                   child: Column(
                     children: [
                       SwitchListTile(
                         title: const Text("Dark Mode"),
                         secondary: Icon(Icons.dark_mode, color: themeService.isDarkMode ? Colors.yellow : Colors.grey),
                         value: themeService.isDarkMode,
                         onChanged: (val) => themeService.toggleTheme(val),
                       ),
                       const Divider(indent: 16, endIndent: 16),
                       ListTile(
                         leading: const Icon(Icons.logout, color: Colors.redAccent),
                         title: const Text("Log Out", style: TextStyle(color: Colors.redAccent)),
                         onTap: () async {
                            await authService.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const OnboardingScreen()), 
                                (route) => false
                              );
                            }
                         },
                       )
                     ],
                   ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
