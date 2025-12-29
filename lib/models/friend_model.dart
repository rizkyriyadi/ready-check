import 'package:cloud_firestore/cloud_firestore.dart';

class Friend {
  final String uid;
  final String displayName;
  final String photoUrl;
  final DateTime addedAt;

  Friend({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.addedAt,
  });

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friend(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}

class FriendRequest {
  final String fromUid;
  final String fromName;
  final String fromPhoto;
  final DateTime sentAt;

  FriendRequest({
    required this.fromUid,
    required this.fromName,
    required this.fromPhoto,
    required this.sentAt,
  });

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      fromUid: doc.id,
      fromName: data['fromName'] ?? '',
      fromPhoto: data['fromPhoto'] ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DirectChat {
  final String id;
  final List<String> participants;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  DirectChat({
    required this.id,
    required this.participants,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhoto,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory DirectChat.fromFirestore(DocumentSnapshot doc, String currentUid) {
    final data = doc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUid = participants.firstWhere((p) => p != currentUid, orElse: () => '');
    
    // Get unread count for current user
    final unreadCounts = data['unreadCount'] as Map<String, dynamic>?;
    final unread = unreadCounts?[currentUid] ?? 0;
    
    return DirectChat(
      id: doc.id,
      participants: participants,
      otherUserId: otherUid,
      otherUserName: data['userNames']?[otherUid] ?? 'User',
      otherUserPhoto: data['userPhotos']?[otherUid] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: unread is int ? unread : 0,
    );
  }
}

class AppUser {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String email;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.email,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      email: data['email'] ?? '',
    );
  }
}
