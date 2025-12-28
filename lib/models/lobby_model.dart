import 'package:cloud_firestore/cloud_firestore.dart';

class Lobby {
  final String id;
  final String code;
  final String hostId;
  final bool isChecking;
  final DateTime createdAt;

  Lobby({
    required this.id,
    required this.code,
    required this.hostId,
    this.isChecking = false,
    required this.createdAt,
  });

  factory Lobby.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lobby(
      id: doc.id,
      code: data['code'] ?? '',
      hostId: data['hostId'] ?? '',
      isChecking: data['isChecking'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'hostId': hostId,
      'isChecking': isChecking,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class Participant {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String status; // 'idle', 'ready', 'not_ready'

  Participant({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    this.status = 'idle',
  });

  factory Participant.fromMap(Map<String, dynamic> data, String uid) {
    return Participant(
      uid: uid,
      displayName: data['displayName'] ?? 'Unknown',
      photoUrl: data['photoUrl'] ?? '',
      status: data['status'] ?? 'idle',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'status': status,
    };
  }
}
