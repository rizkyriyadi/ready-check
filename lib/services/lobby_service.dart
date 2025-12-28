import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ready_check/models/lobby_model.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LobbyService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _prefsKeyLobbyId = 'current_lobby_id';

  // --- Persistence ---
  Future<String?> checkCurrentLobby() async {
    final prefs = await SharedPreferences.getInstance();
    final lobbyId = prefs.getString(_prefsKeyLobbyId);

    if (lobbyId != null) {
      final doc = await _firestore.collection('lobbies').doc(lobbyId).get();
      if (doc.exists) {
        return lobbyId;
      } else {
        await prefs.remove(_prefsKeyLobbyId);
      }
    }
    return null;
  }

  // --- Core Lobby ---

  String _generateLobbyCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<Lobby?> createLobby() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final code = _generateLobbyCode();
      final lobbyRef = _firestore.collection('lobbies').doc();

      final lobby = Lobby(
        id: lobbyRef.id,
        code: code,
        hostId: user.uid,
        createdAt: DateTime.now(),
      );

      await lobbyRef.set(lobby.toMap());
      await joinLobby(code, lobbyId: lobbyRef.id);
      return lobby;
    } catch (e) {
      debugPrint("Error creating lobby: $e");
      return null;
    }
  }

  Future<String?> joinLobby(String code, {String? lobbyId}) async {
    final user = _auth.currentUser;
    if (user == null) return "User not logged in";

    try {
      String id = lobbyId ?? '';
      
      if (id.isEmpty) {
        final querySnapshot = await _firestore
            .collection('lobbies')
            .where('code', isEqualTo: code)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          return "Lobby not found";
        }
        id = querySnapshot.docs.first.id;
      }

      final participantRef = _firestore
          .collection('lobbies')
          .doc(id)
          .collection('participants')
          .doc(user.uid);

      final participant = Participant(
        uid: user.uid,
        displayName: user.displayName ?? 'Unknown',
        photoUrl: user.photoURL ?? '',
        status: 'idle',
      );

      await participantRef.set(participant.toMap());
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyLobbyId, id);

      return id;
    } catch (e) {
      debugPrint("Error joining lobby: $e");
      return "Failed to join: $e";
    }
  }

  Future<void> leaveLobby(String lobbyId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _firestore
          .collection('lobbies')
          .doc(lobbyId)
          .collection('participants')
          .doc(user.uid)
          .delete();
          
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyLobbyId);
    } catch (e) {
      debugPrint("Error leaving lobby: $e");
    }
  }

  Stream<Lobby> streamLobby(String lobbyId) {
    return _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .snapshots()
        .map((doc) => Lobby.fromFirestore(doc));
  }

  Stream<List<Participant>> streamParticipants(String lobbyId) {
    return _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Participant.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> setReadyStatus(String lobbyId, String status) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection('participants')
        .doc(user.uid)
        .update({'status': status});
  }

  Future<void> startReadyCheck(String lobbyId) async {
    await _firestore.collection('lobbies').doc(lobbyId).update({
      'isChecking': true,
      'startTime': FieldValue.serverTimestamp(),
    });
    
    final participants = await _firestore.collection('lobbies').doc(lobbyId).collection('participants').get();
    final batch = _firestore.batch();
    for (var doc in participants.docs) {
      batch.update(doc.reference, {'status': 'waiting'});
    }
    await batch.commit();
  }

  Future<void> cancelReadyCheck(String lobbyId) async {
    await _firestore.collection('lobbies').doc(lobbyId).update({'isChecking': false});
    
    final participants = await _firestore.collection('lobbies').doc(lobbyId).collection('participants').get();
    final batch = _firestore.batch();
    for (var doc in participants.docs) {
      batch.update(doc.reference, {'status': 'idle'});
    }
    await batch.commit();
  }

  // --- Chat ---

  Future<void> sendMessage(String lobbyId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    final message = Message(
      id: '', 
      senderId: user.uid,
      senderName: user.displayName ?? 'Unknown',
      senderPhotoUrl: user.photoURL ?? '',
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection('messages')
        .add(message.toMap());
  }

  Stream<List<Message>> streamMessages(String lobbyId) {
    return _firestore
        .collection('lobbies')
        .doc(lobbyId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }
}
