import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/services/lobby_service.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/widgets/primary_button.dart';
import 'package:ready_check/screens/onboarding_screen.dart';
import 'package:ready_check/screens/lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkExistingLobby();
  }

  Future<void> _checkExistingLobby() async {
    // Only check if widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       final lobbyService = Provider.of<LobbyService>(context, listen: false);
       final savedLobbyId = await lobbyService.checkCurrentLobby();
       
       if (savedLobbyId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Rejoining previous session...")),
          );
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LobbyScreen(lobbyId: savedLobbyId)),
          );
       }
    });
  }

  void _showProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ProfileModal(),
    );
  }

  Future<void> _handleCreateLobby(BuildContext context) async {
    final lobbyService = Provider.of<LobbyService>(context, listen: false);
    final lobby = await lobbyService.createLobby();
    
    if (lobby != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LobbyScreen(lobbyId: lobby.id)),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to create lobby")),
      );
    }
  }

  void _showJoinDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Join Squad"),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: "Enter 6-digit Code",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 6) return;
              
              Navigator.pop(dialogContext); 
              
              final lobbyService = Provider.of<LobbyService>(context, listen: false);
              
              final result = await lobbyService.joinLobby(code);
              
              if (result != null && !result.startsWith("Failed") && !result.startsWith("Lobby not found")) {
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LobbyScreen(lobbyId: result)),
                  );
                }
              } else if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result ?? "Error joining")),
                );
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ready Check"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: UserAvatar(
              photoUrl: user?.photoURL,
              onTap: () => _showProfileModal(context),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                text: "Create Squad",
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _handleCreateLobby(context),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _showJoinDialog(context),
                icon: const Icon(Icons.input),
                label: const Text("Join Squad"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(30),
                  ),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileModal extends StatelessWidget {
  const _ProfileModal();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          UserAvatar(
            photoUrl: user?.photoURL,
            radius: 40,
          ),
          const SizedBox(height: 16),
          Text(
            user?.displayName ?? "Unknown User",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            user?.email ?? "No Email",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    (route) => false,
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[400],
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text("Log Out"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
