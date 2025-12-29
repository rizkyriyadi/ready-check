import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/call_model.dart';
import 'package:ready_check/services/call_service.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/screens/call/incoming_call_overlay.dart';

class IncomingCallListener extends StatefulWidget {
  final Widget child;

  const IncomingCallListener({super.key, required this.child});

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  StreamSubscription<Call?>? _callSubscription;
  String? _currentIncomingCallId;
  bool _isShowingOverlay = false;

  @override
  void initState() {
    super.initState();
    _initListener();
  }

  void _initListener() {
    // Wait for auth to be ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final callService = Provider.of<CallService>(context, listen: false);

      // Re-init when auth changes
      authService.addListener(() {
        _setupCallListener(callService);
      });

      _setupCallListener(callService);
    });
  }

  void _setupCallListener(CallService callService) {
    _callSubscription?.cancel();

    if (callService.currentUid == null) return;

    _callSubscription = callService.streamIncomingCall().listen((call) {
      if (call != null && 
          call.id != _currentIncomingCallId && 
          call.callerId != callService.currentUid &&
          !_isShowingOverlay) {
        _showIncomingCall(call);
      }
    });
  }

  void _showIncomingCall(Call call) {
    if (!mounted) return;

    _currentIncomingCallId = call.id;
    _isShowingOverlay = true;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return IncomingCallOverlay(call: call);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) {
      _isShowingOverlay = false;
      _currentIncomingCallId = null;
    });
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
