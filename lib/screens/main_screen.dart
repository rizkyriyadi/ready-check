import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/screens/circles/circle_list_page.dart';
import 'package:ready_check/screens/chat/messages_list_page.dart';
import 'package:ready_check/screens/friends/friends_hub_page.dart';
import 'package:ready_check/screens/profile/profile_page.dart';
import 'package:ready_check/services/session_service.dart';
import 'package:ready_check/services/update_service.dart';
import 'package:ready_check/screens/session/ready_check_overlay.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/update_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _summonSubscription;
  String? _lastHandledSessionId;
  
  final List<Widget> _pages = [
    const CircleListPage(),
    const MessagesListPage(),
    const FriendsHubPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _initSummonListener();
    _checkForUpdates();
  }
  
  /// Check for OTA updates on app start
  void _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 2)); // Wait for UI to settle
    if (!mounted) return;
    
    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdate();
    
    if (updateInfo != null && mounted) {
      showUpdateDialog(context, updateInfo);
    }
  }
  
  void _initSummonListener() {
    // Post-frame callback to ensure context is available and provider is accessible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionService = Provider.of<SessionService>(context, listen: false);
      _summonSubscription = sessionService.streamIncomingSummon().listen((session) {
         if (session != null && session.id != _lastHandledSessionId) {
             // Filter out old sessions (older than 5 minutes)
             final createdAt = session.createdAt;
             if (DateTime.now().difference(createdAt).inMinutes.abs() > 5) {
               return;
             }

             // New Summon Found!
             _lastHandledSessionId = session.id;
             
             if (mounted) {
               Navigator.of(context).push(
                 MaterialPageRoute(builder: (_) => ReadyCheckOverlay(sessionId: session.id))
               );
             }
         }
      });
    });
  }

  @override
  void dispose() {
    _summonSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        child: GlassContainer(
           blur: 15,
           opacity: 0.7, 
           borderRadius: BorderRadius.circular(30),
           child: NavigationBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            selectedIndex: _selectedIndex,
            height: 65, 
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                 icon: Icon(Icons.group_outlined),
                 selectedIcon: Icon(Icons.group),
                 label: 'Circles',
              ),
              NavigationDestination(
                 icon: Icon(Icons.chat_bubble_outline),
                 selectedIcon: Icon(Icons.chat_bubble),
                 label: 'Messages',
              ),
              NavigationDestination(
                 icon: Icon(Icons.people_outline),
                 selectedIcon: Icon(Icons.people),
                 label: 'Friends',
              ),
              NavigationDestination(
                 icon: Icon(Icons.person_outline),
                 selectedIcon: Icon(Icons.person),
                 label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
