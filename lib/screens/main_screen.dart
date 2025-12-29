import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/screens/circles/circle_list_page.dart';
import 'package:ready_check/screens/chat/messages_list_page.dart';
import 'package:ready_check/screens/friends/friends_hub_page.dart';
import 'package:ready_check/screens/profile/profile_page.dart';
import 'package:ready_check/screens/call/call_history_page.dart';
import 'package:ready_check/services/session_service.dart';
import 'package:ready_check/services/call_service.dart';
import 'package:ready_check/services/update_service.dart';
import 'package:ready_check/screens/session/ready_check_overlay.dart';
import 'package:ready_check/screens/call/incoming_call_overlay.dart';
import 'package:ready_check/screens/widgets/glass_nav_bar.dart';
import 'package:ready_check/screens/widgets/update_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _summonSubscription;
  StreamSubscription? _callSubscription;
  String? _lastHandledSessionId;
  String? _lastHandledCallId;
  
  final List<Widget> _pages = [
    const CircleListPage(),
    const CallHistoryPage(),
    const MessagesListPage(),
    const FriendsHubPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _initSummonListener();
    _initCallListener();
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

  void _initCallListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callService = Provider.of<CallService>(context, listen: false);
      _callSubscription = callService.streamIncomingCall().listen((call) {
        if (call != null && call.id != _lastHandledCallId) {
          _lastHandledCallId = call.id;
          
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => IncomingCallOverlay(call: call))
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _summonSubscription?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      backgroundColor: const Color(0xFF101010), // Deep dark background
      body: Stack(
        children: [
          // Content
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          
          // Custom Float Glass Dock
          GlassBottomNavBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: [
               GlassNavBarItem(icon: Icons.group_work_outlined, selectedIcon: Icons.group_work, label: 'Circles'),
               GlassNavBarItem(icon: Icons.call_outlined, selectedIcon: Icons.call, label: 'Calls'),
               GlassNavBarItem(icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, label: 'Chats'),
               GlassNavBarItem(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Friends'),
               GlassNavBarItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
            ],
          ),
        ],
      ),
    );
  }
}
