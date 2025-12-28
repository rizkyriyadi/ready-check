import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ready_check/models/circle_model.dart';
import 'package:ready_check/models/chat_model.dart';

class CircleService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, O, 1, 0
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

  // Send Message (Persistent)
  Future<void> sendCircleMessage(String circleId, String text) async {
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
        .collection('circles')
        .doc(circleId)
        .collection('messages')
        .add(msg.toMap());
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
}
