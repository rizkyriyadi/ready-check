import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:ready_check/models/friend_model.dart';

class DirectChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
          'unreadCount': {uid: 0, otherUid: 0},
          'typing': {uid: false, otherUid: false},
        });
      }

      return chatId;
    } catch (e) {
      debugPrint('Error creating chat: $e');
      return null;
    }
  }

  /// Send a text message
  Future<bool> sendMessage(String chatId, String text, {String? replyToId, String? replyToText}) async {
    final uid = currentUid;
    if (uid == null || text.trim().isEmpty) return false;

    try {
      final currentUser = _auth.currentUser!;
      
      final messageData = {
        'senderId': uid,
        'senderName': currentUser.displayName ?? 'Anonymous',
        'senderPhotoUrl': currentUser.photoURL ?? '',
        'text': text.trim(),
        'imageUrl': null,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'readAt': null,
      };

      // Add message
      await _firestore
          .collection('directChats').doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update last message and increment unread for other user
      final chatDoc = await _firestore.collection('directChats').doc(chatId).get();
      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherUid = participants.firstWhere((p) => p != uid, orElse: () => '');
      
      await _firestore.collection('directChats').doc(chatId).update({
        'lastMessage': text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.$otherUid': FieldValue.increment(1),
        'typing.$uid': false,
      });

      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  /// Send a photo message
  Future<bool> sendPhoto(String chatId, File imageFile, {String? replyToId, String? replyToText}) async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      final currentUser = _auth.currentUser!;
      
      // Upload image
      final fileName = 'dm_${chatId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('chat_images/$fileName');
      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();
      
      final messageData = {
        'senderId': uid,
        'senderName': currentUser.displayName ?? 'Anonymous',
        'senderPhotoUrl': currentUser.photoURL ?? '',
        'text': '📷 Photo',
        'imageUrl': imageUrl,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'readAt': null,
      };

      await _firestore
          .collection('directChats').doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update last message
      final chatDoc = await _firestore.collection('directChats').doc(chatId).get();
      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherUid = participants.firstWhere((p) => p != uid, orElse: () => '');
      
      await _firestore.collection('directChats').doc(chatId).update({
        'lastMessage': '📷 Photo',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.$otherUid': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      debugPrint('Error sending photo: $e');
      return false;
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatId) async {
    final uid = currentUid;
    if (uid == null) return;

    try {
      // Reset unread count for current user
      await _firestore.collection('directChats').doc(chatId).update({
        'unreadCount.$uid': 0,
      });

      // Mark unread messages as read
      final unreadMessages = await _firestore
          .collection('directChats').doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: uid)
          .where('readAt', isNull: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'readAt': FieldValue.serverTimestamp(),
          'status': 'read',
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  /// Set typing status
  Future<void> setTyping(String chatId, bool isTyping) async {
    final uid = currentUid;
    if (uid == null) return;

    try {
      await _firestore.collection('directChats').doc(chatId).update({
        'typing.$uid': isTyping,
      });
    } catch (e) {
      debugPrint('Error setting typing: $e');
    }
  }

  /// Stream typing status of other user
  Stream<bool> streamTypingStatus(String chatId) {
    final uid = currentUid;
    if (uid == null) return Stream.value(false);

    return _firestore.collection('directChats').doc(chatId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return false;
      final typing = data['typing'] as Map<String, dynamic>?;
      if (typing == null) return false;
      
      // Return true if any other participant is typing
      return typing.entries
          .where((e) => e.key != uid)
          .any((e) => e.value == true);
    });
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
