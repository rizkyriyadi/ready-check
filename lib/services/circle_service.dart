import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:ready_check/models/circle_model.dart';
import 'package:ready_check/models/chat_model.dart';

class CircleService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // Create Circle
  Future<String?> createCircle(String name) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docRef = _firestore.collection('circles').doc();
      final code = _generateCode();
      
      final circle = Circle(
        id: docRef.id,
        name: name,
        code: code,
        memberIds: [user.uid],
        createdAt: DateTime.now(),
      );

      await docRef.set(circle.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint("Error creating circle: $e");
      return null;
    }
  }

  // Join Circle
  Future<bool> joinCircle(String code) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await _firestore
          .collection('circles')
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return false;

      final doc = snapshot.docs.first;
      await doc.reference.update({
        'memberIds': FieldValue.arrayUnion([user.uid])
      });
      return true;
    } catch (e) {
      debugPrint("Error joining circle: $e");
      return false;
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Get My Circles
  Stream<List<Circle>> streamMyCircles() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('circles')
        .where('memberIds', arrayContains: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Circle.fromFirestore(doc)).toList());
  }

  // Get Single Circle
  Stream<Circle> streamCircle(String circleId) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .snapshots()
        .map((doc) => Circle.fromFirestore(doc));
  }

  // Send Text Message with optional reply
  Future<void> sendCircleMessage(String circleId, String text, {String? replyToId, String? replyToText}) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    await _firestore
        .collection('circles')
        .doc(circleId)
        .collection('messages')
        .add({
          'senderId': user.uid,
          'senderName': user.displayName ?? 'Unknown',
          'senderPhotoUrl': user.photoURL ?? '',
          'text': text.trim(),
          'imageUrl': null,
          'replyToId': replyToId,
          'replyToText': replyToText,
          'status': 'sent',
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Clear typing
    await setTyping(circleId, false);
  }

  // Send Photo Message
  Future<bool> sendPhoto(String circleId, File imageFile, {String? replyToId, String? replyToText}) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final fileName = 'circle_${circleId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('chat_images/$fileName');
      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      await _firestore
          .collection('circles')
          .doc(circleId)
          .collection('messages')
          .add({
            'senderId': user.uid,
            'senderName': user.displayName ?? 'Unknown',
            'senderPhotoUrl': user.photoURL ?? '',
            'text': '📷 Photo',
            'imageUrl': imageUrl,
            'replyToId': replyToId,
            'replyToText': replyToText,
            'status': 'sent',
            'timestamp': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      debugPrint('Error sending photo: $e');
      return false;
    }
  }

  // Typing indicator
  Future<void> setTyping(String circleId, bool isTyping) async {
    final uid = currentUid;
    if (uid == null) return;

    try {
      await _firestore.collection('circles').doc(circleId).update({
        'typing.$uid': isTyping,
      });
    } catch (e) {
      debugPrint('Error setting typing: $e');
    }
  }

  // Stream typing members (returns list of user names currently typing)
  Stream<List<String>> streamTypingMembers(String circleId) {
    final uid = currentUid;
    if (uid == null) return Stream.value([]);

    return _firestore.collection('circles').doc(circleId).snapshots().asyncMap((snap) async {
      final data = snap.data();
      if (data == null) return <String>[];
      
      final typing = data['typing'] as Map<String, dynamic>?;
      if (typing == null) return <String>[];
      
      final typingUserIds = typing.entries
          .where((e) => e.key != uid && e.value == true)
          .map((e) => e.key)
          .toList();

      if (typingUserIds.isEmpty) return <String>[];

      // Get user names
      final names = <String>[];
      for (final userId in typingUserIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final name = userDoc.data()?['displayName'] ?? 'Someone';
        names.add(name);
      }
      return names;
    });
  }

  // Stream Messages
  Stream<List<Message>> streamCircleMessages(String circleId) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  // ==================== Circle Management ====================

  // Update circle name
  Future<bool> updateCircleName(String circleId, String newName) async {
    if (newName.trim().isEmpty) return false;

    try {
      await _firestore.collection('circles').doc(circleId).update({
        'name': newName.trim(),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating circle name: $e');
      return false;
    }
  }

  // Update circle photo
  Future<bool> updateCirclePhoto(String circleId, File imageFile) async {
    try {
      final fileName = 'circle_photo_${circleId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('circle_images/$circleId/$fileName');
      await ref.putFile(imageFile);
      final photoUrl = await ref.getDownloadURL();

      await _firestore.collection('circles').doc(circleId).update({
        'photoUrl': photoUrl,
      });
      return true;
    } catch (e) {
      debugPrint('Error updating circle photo: $e');
      return false;
    }
  }

  // Leave circle
  Future<bool> leaveCircle(String circleId) async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      await _firestore.collection('circles').doc(circleId).update({
        'memberIds': FieldValue.arrayRemove([uid]),
        'typing.$uid': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      debugPrint('Error leaving circle: $e');
      return false;
    }
  }

  // Add member by UID
  Future<bool> addMember(String circleId, String userId) async {
    try {
      await _firestore.collection('circles').doc(circleId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding member: $e');
      return false;
    }
  }

  // Get circle members info
  Future<List<Map<String, dynamic>>> getCircleMembers(String circleId) async {
    try {
      final circleDoc = await _firestore.collection('circles').doc(circleId).get();
      final memberIds = List<String>.from(circleDoc.data()?['memberIds'] ?? []);
      
      final members = <Map<String, dynamic>>[];
      for (final uid in memberIds) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          members.add({
            'uid': uid,
            'displayName': userDoc.data()?['displayName'] ?? 'Unknown',
            'photoUrl': userDoc.data()?['photoUrl'] ?? '',
          });
        }
      }
      return members;
    } catch (e) {
      debugPrint('Error getting members: $e');
      return [];
    }
  }
}
