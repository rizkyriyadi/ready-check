import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ready_check/models/session_model.dart';
import 'package:ready_check/models/lobby_model.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _prefsKeySessionId = 'current_session_id';

  // --- Persistence ---
  Future<String?> checkCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_prefsKeySessionId);

    if (sessionId != null) {
      final doc = await _firestore.collection('sessions').doc(sessionId).get();
      if (doc.exists) {
        return sessionId;
      } else {
        await prefs.remove(_prefsKeySessionId);
      }
    }
    return null;
  }

  // --- Core Session ---

  Future<String?> createSession({
    required String activityTitle,
    String? circleId,
    int requiredSlots = 5,
    bool isPublic = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      List<String> participantIds = [user.uid];
      int finalSlots = requiredSlots;

      // Logic: If Circle ID provided, fetch members
      if (circleId != null) {
        final circleDoc = await _firestore.collection('circles').doc(circleId).get();
        if (circleDoc.exists) {
           final data = circleDoc.data();
           if (data != null && data['memberIds'] is List) {
              final members = List<String>.from(data['memberIds']);
              participantIds = members; // All members
              finalSlots = members.length;
           }
        }
      }

      final docRef = _firestore.collection('sessions').doc();
      final session = Session(
        id: docRef.id,
        hostId: user.uid,
        circleId: circleId,
        activityTitle: activityTitle,
        requiredSlots: finalSlots,
        participants: participantIds,
        isPublic: isPublic,
        createdAt: DateTime.now(),
      );

      await docRef.set(session.toMap());
      
      // Add each participant with their REAL user data from Firestore
      for (final pid in participantIds) {
         final isHost = pid == user.uid;
         String displayName = 'Unknown';
         String photoUrl = '';
         
         if (isHost) {
           displayName = user.displayName ?? 'Unknown';
           photoUrl = user.photoURL ?? '';
         } else {
           // Fetch user data from users collection
           try {
             final userDoc = await _firestore.collection('users').doc(pid).get();
             if (userDoc.exists) {
               displayName = userDoc.data()?['displayName'] ?? 'Unknown';
               photoUrl = userDoc.data()?['photoUrl'] ?? '';
             }
           } catch (e) {
             debugPrint('Error fetching user $pid: $e');
           }
         }
         
         await _firestore.collection('sessions').doc(docRef.id).collection('participants').doc(pid).set({
           'uid': pid,
           'displayName': displayName, 
           'photoUrl': photoUrl, 
           'status': isHost ? 'ready' : 'waiting', 
         });
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeySessionId, docRef.id);

      return docRef.id;
    } catch (e) {
      debugPrint("Error creating session: $e");
      return null;
    }
  }

  Future<bool> joinSession(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final sessionRef = _firestore.collection('sessions').doc(sessionId);
      await sessionRef.update({
        'participants': FieldValue.arrayUnion([user.uid])
      });
      
      await _addParticipant(sessionId, user);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeySessionId, sessionId);
      
      return true;
    } catch (e) {
      debugPrint("Error joining session: $e");
      return false;
    }
  }
  
  Future<void> leaveSession(String sessionId) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove(_prefsKeySessionId);
  }

  Future<void> _addParticipant(String sessionId, User user, {bool isHost = false}) async {
    final p = Participant(
      uid: user.uid,
      displayName: user.displayName ?? 'Unknown',
      photoUrl: user.photoURL ?? '',
      status: isHost ? 'ready' : 'idle',
    );
    
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('participants')
        .doc(user.uid)
        .set(p.toMap());
  }

  Stream<List<Session>> streamPublicSessions() {
    return _firestore
        .collection('sessions')
        .where('isPublic', isEqualTo: true)
        .where('status', isEqualTo: 'collecting')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList());
  }
  
  Stream<Session> streamSession(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => Session.fromFirestore(doc));
  }

  Stream<List<Participant>> streamSessionParticipants(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('participants')
        .snapshots()
        .map((s) => s.docs.map((d) => Participant.fromMap(d.data(), d.id)).toList());
  }
  
  // New: Stream Incoming Summons (Simplified query to avoid composite index)
  Stream<Session?> streamIncomingSummon() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    
    // Simple query: just participants + status. No orderBy to avoid index.
    return _firestore
      .collection('sessions')
      .where('participants', arrayContains: user.uid)
      .where('status', isEqualTo: 'collecting')
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        
        // Client-side: find the most recent session
        final sessions = snapshot.docs.map((d) => Session.fromFirestore(d)).toList();
        sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
        return sessions.first;
      });
  }

  // --- Mini-Chat ---
  
  Stream<List<Message>> streamSessionMessages(String sessionId) {
     return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }
  
  Future<void> sendSessionMessage(String sessionId, String text) async {
     final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    final msg = Message(
      id: '',
      senderId: user.uid,
      senderName: user.displayName ?? 'Unknown',
      senderPhotoUrl: user.photoURL ?? '',
      text: text.trim(),
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .add(msg.toMap());
  }
  
  Future<void> setReadyStatus(String sessionId, String status) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore.collection('sessions').doc(sessionId).collection('participants')
      .doc(user.uid).update({'status': status});
  }
}
