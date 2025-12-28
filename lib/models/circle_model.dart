import 'package:cloud_firestore/cloud_firestore.dart';

class Circle {
  final String id;
  final String name; 
  final String photoUrl; 
  final String code; // New field for joining
  final List<String> memberIds;
  final DateTime createdAt;

  Circle({
    required this.id,
    required this.name,
    this.photoUrl = '',
    required this.code,
    required this.memberIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'code': code,
      'memberIds': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Circle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Circle(
      id: doc.id,
      name: data['name'] ?? 'Untitled Circle',
      photoUrl: data['photoUrl'] ?? '',
      code: data['code'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
