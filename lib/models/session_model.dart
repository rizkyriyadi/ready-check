import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String hostId;
  final String? circleId; // Nullable if created publicly without a circle (optional, but requested logic implies sessions come from circles or are public)
  final String activityTitle; // "Dota 2 - Rank Legend"
  final String description; // "Looking for Tank"
  final int requiredSlots; // e.g., 5
  final List<String> participants; // IDs of everyone (Host + Circle Members + Guests)
  final bool isPublic; // To show on Explore Board
  final String status; // 'collecting', 'ready', 'in_game'
  final DateTime createdAt;

  Session({
    required this.id,
    required this.hostId,
    this.circleId,
    required this.activityTitle,
    this.description = '',
    this.requiredSlots = 5,
    required this.participants,
    this.isPublic = true,
    this.status = 'collecting',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'circleId': circleId,
      'activityTitle': activityTitle,
      'description': description,
      'requiredSlots': requiredSlots,
      'participants': participants,
      'isPublic': isPublic,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      circleId: data['circleId'],
      activityTitle: data['activityTitle'] ?? 'Game Session',
      description: data['description'] ?? '',
      requiredSlots: data['requiredSlots'] ?? 5,
      participants: List<String>.from(data['participants'] ?? []),
      isPublic: data['isPublic'] ?? true,
      status: data['status'] ?? 'collecting',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
