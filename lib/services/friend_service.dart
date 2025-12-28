import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ready_check/models/friend_model.dart';

class FriendService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  /// Send a friend request to another user
  Future<bool> sendFriendRequest(String toUid) async {
    final uid = currentUid;
    if (uid == null || uid == toUid) return false;

    try {
      final currentUser = _auth.currentUser!;
      
      // Check if already friends
      final friendDoc = await _firestore
          .collection('users').doc(uid)
          .collection('friends').doc(toUid).get();
      if (friendDoc.exists) {
        debugPrint('Already friends');
        return false;
      }

      // Check if request already sent
      final sentDoc = await _firestore
          .collection('users').doc(uid)
          .collection('sentRequests').doc(toUid).get();
      if (sentDoc.exists) {
        debugPrint('Request already sent');
        return false;
      }

      // Add to target's friendRequests
      await _firestore
          .collection('users').doc(toUid)
          .collection('friendRequests').doc(uid)
          .set({
            'fromName': currentUser.displayName ?? 'Anonymous',
            'fromPhoto': currentUser.photoURL ?? '',
            'sentAt': FieldValue.serverTimestamp(),
          });

      // Track in our sentRequests
      await _firestore
          .collection('users').doc(uid)
          .collection('sentRequests').doc(toUid)
          .set({'sentAt': FieldValue.serverTimestamp()});

      return true;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      return false;
    }
  }

  /// Accept a friend request
  Future<bool> acceptFriendRequest(String fromUid) async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      // Get request details
      final requestDoc = await _firestore
          .collection('users').doc(uid)
          .collection('friendRequests').doc(fromUid).get();
      
      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data()!;
      final currentUser = _auth.currentUser!;

      // Add each other as friends
      final batch = _firestore.batch();

      // Add fromUid to my friends
      batch.set(
        _firestore.collection('users').doc(uid).collection('friends').doc(fromUid),
        {
          'displayName': requestData['fromName'],
          'photoUrl': requestData['fromPhoto'],
          'addedAt': FieldValue.serverTimestamp(),
        }
      );

      // Add me to their friends
      batch.set(
        _firestore.collection('users').doc(fromUid).collection('friends').doc(uid),
        {
          'displayName': currentUser.displayName ?? 'Anonymous',
          'photoUrl': currentUser.photoURL ?? '',
          'addedAt': FieldValue.serverTimestamp(),
        }
      );

      // Remove the request
      batch.delete(_firestore.collection('users').doc(uid).collection('friendRequests').doc(fromUid));
      batch.delete(_firestore.collection('users').doc(fromUid).collection('sentRequests').doc(uid));

      await batch.commit();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      return false;
    }
  }

  /// Reject a friend request
  Future<bool> rejectFriendRequest(String fromUid) async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      await _firestore
          .collection('users').doc(uid)
          .collection('friendRequests').doc(fromUid)
          .delete();
      
      await _firestore
          .collection('users').doc(fromUid)
          .collection('sentRequests').doc(uid)
          .delete();

      return true;
    } catch (e) {
      debugPrint('Error rejecting friend request: $e');
      return false;
    }
  }

  /// Remove a friend
  Future<bool> removeFriend(String friendUid) async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('users').doc(uid).collection('friends').doc(friendUid));
      batch.delete(_firestore.collection('users').doc(friendUid).collection('friends').doc(uid));
      await batch.commit();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error removing friend: $e');
      return false;
    }
  }

  /// Stream of friends list
  Stream<List<Friend>> streamFriends() {
    final uid = currentUid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('users').doc(uid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Friend.fromFirestore(d)).toList());
  }

  /// Stream of friend requests
  Stream<List<FriendRequest>> streamFriendRequests() {
    final uid = currentUid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('users').doc(uid)
        .collection('friendRequests')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FriendRequest.fromFirestore(d)).toList());
  }

  /// Get user by ID
  Future<AppUser?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  /// Check friendship status
  Future<String> getFriendshipStatus(String otherUid) async {
    final uid = currentUid;
    if (uid == null || uid == otherUid) return 'self';

    try {
      // Check if friends
      final friendDoc = await _firestore
          .collection('users').doc(uid)
          .collection('friends').doc(otherUid).get();
      if (friendDoc.exists) return 'friend';

      // Check if request sent
      final sentDoc = await _firestore
          .collection('users').doc(uid)
          .collection('sentRequests').doc(otherUid).get();
      if (sentDoc.exists) return 'pending';

      // Check if request received
      final requestDoc = await _firestore
          .collection('users').doc(uid)
          .collection('friendRequests').doc(otherUid).get();
      if (requestDoc.exists) return 'incoming';

      return 'none';
    } catch (e) {
      return 'none';
    }
  }
}
