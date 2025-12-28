import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:ready_check/models/friend_model.dart';

class DirectChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  /// Get or create a direct chat with another user
  Future<String?> getOrCreateChat(String otherUid) async {
    final uid = currentUid;
    if (uid == null) return null;

    try {
      // Generate deterministic chat ID (smaller UID first)
      final chatId = uid.compareTo(otherUid) < 0 
          ? '${uid}_$otherUid' 
          : '${otherUid}_$uid';

      final chatDoc = await _firestore.collection('directChats').doc(chatId).get();

      if (!chatDoc.exists) {
        // Get other user's info
        final otherUserDoc = await _firestore.collection('users').doc(otherUid).get();
        final otherUserData = otherUserDoc.data() ?? {};
        
        final currentUser = _auth.currentUser!;

        // Create new chat
        await _firestore.collection('directChats').doc(chatId).set({
          'participants': [uid, otherUid],
          'userNames': {
            uid: currentUser.displayName ?? 'Anonymous',
            otherUid: otherUserData['displayName'] ?? 'User',
          },
          'userPhotos': {
            uid: currentUser.photoURL ?? '',
            otherUid: otherUserData['photoUrl'] ?? '',
          },
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return chatId;
    } catch (e) {
      debugPrint('Error creating chat: $e');
      return null;
    }
  }

  /// Send a message in a direct chat
  Future<bool> sendMessage(String chatId, String text) async {
    final uid = currentUid;
    if (uid == null || text.trim().isEmpty) return false;

    try {
      final currentUser = _auth.currentUser!;
      
      final messageData = {
        'senderId': uid,
        'senderName': currentUser.displayName ?? 'Anonymous',
        'senderPhoto': currentUser.photoURL ?? '',
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
      };

      // Add message
      await _firestore
          .collection('directChats').doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update last message
      await _firestore.collection('directChats').doc(chatId).update({
        'lastMessage': text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Stream messages in a chat
  Stream<List<Message>> streamMessages(String chatId) {
    return _firestore
        .collection('directChats').doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Message.fromFirestore(d)).toList());
  }

  /// Stream user's direct chats
  Stream<List<DirectChat>> streamUserChats() {
    final uid = currentUid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('directChats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DirectChat.fromFirestore(d, uid)).toList());
  }
}
