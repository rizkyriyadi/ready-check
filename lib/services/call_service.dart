import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ready_check/models/call_model.dart';

class CallService extends ChangeNotifier {
  static const String appId = '4aae908d259f4674aeb70b252110a314';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  List<int> _remoteUsers = [];
  String? _currentCallId;
  
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  List<int> get remoteUsers => _remoteUsers;
  String? get currentCallId => _currentCallId;
  String? get currentUid => _auth.currentUser?.uid;

  // Initialize Agora Engine
  Future<bool> initializeEngine() async {
    if (_isInitialized) return true;
    
    try {
      // Request permissions
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        debugPrint('Microphone permission denied');
        return false;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Set up event handlers
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('Joined channel: ${connection.channelId}');
          // Set speaker after join success
          _engine?.setEnableSpeakerphone(true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('Remote user joined: $remoteUid');
          _remoteUsers.add(remoteUid);
          notifyListeners();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('Remote user left: $remoteUid');
          _remoteUsers.remove(remoteUid);
          notifyListeners();
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora Error: $err - $msg');
        },
      ));

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();
      
      _isInitialized = true;
      debugPrint('Agora initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      return false;
    }
  }

  // Start a call (1-on-1 or group)
  Future<String?> startCall({
    required List<String> receiverIds,
    String? circleId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      if (!await initializeEngine()) return null;

      final callRef = _firestore.collection('calls').doc();
      final channelName = callRef.id;

      final call = Call(
        id: callRef.id,
        channelName: channelName,
        callerId: user.uid,
        callerName: user.displayName ?? 'Unknown',
        callerPhoto: user.photoURL ?? '',
        receiverIds: receiverIds,
        circleId: circleId,
        createdAt: DateTime.now(),
      );

      await callRef.set(call.toMap());
      _currentCallId = callRef.id;

      // Join the channel
      await _engine!.joinChannel(
        token: '', // No token for testing (use token server in production)
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      notifyListeners();
      return callRef.id;
    } catch (e) {
      debugPrint('Error starting call: $e');
      return null;
    }
  }

  // Join an existing call
  Future<bool> joinCall(String callId) async {
    try {
      if (!await initializeEngine()) return false;

      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) return false;

      final call = Call.fromFirestore(callDoc);
      _currentCallId = callId;

      // Update call status to ongoing
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ongoing.name,
      });

      // Join the channel
      await _engine!.joinChannel(
        token: '',
        channelId: call.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error joining call: $e');
      return false;
    }
  }

  // End call
  Future<void> endCall() async {
    try {
      if (_currentCallId != null) {
        await _firestore.collection('calls').doc(_currentCallId).update({
          'status': CallStatus.ended.name,
          'endedAt': FieldValue.serverTimestamp(),
        });
      }

      await _engine?.leaveChannel();
      _remoteUsers.clear();
      _currentCallId = null;
      _isMuted = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  // Decline incoming call
  Future<void> declineCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.declined.name,
      });
    } catch (e) {
      debugPrint('Error declining call: $e');
    }
  }

  // Toggle mute
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine?.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  // Toggle speaker
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _engine?.setEnableSpeakerphone(_isSpeakerOn);
    notifyListeners();
  }

  // Stream incoming calls for current user
  Stream<Call?> streamIncomingCall() {
    final uid = currentUid;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('calls')
        .where('receiverIds', arrayContains: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return Call.fromFirestore(snapshot.docs.first);
        });
  }

  // Stream call status
  Stream<Call?> streamCall(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((doc) => doc.exists ? Call.fromFirestore(doc) : null);
  }

  @override
  void dispose() {
    _engine?.release();
    super.dispose();
  }
}
