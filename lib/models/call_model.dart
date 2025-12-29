import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { ringing, ongoing, ended, declined, missed }
enum CallType { voice, video }

class Call {
  final String id;
  final String channelName;
  final String callerId;
  final String callerName;
  final String callerPhoto;
  final List<String> receiverIds;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? endedAt;
  final String? circleId; // null for 1-on-1, circleId for group calls

  Call({
    required this.id,
    required this.channelName,
    required this.callerId,
    required this.callerName,
    required this.callerPhoto,
    required this.receiverIds,
    this.type = CallType.voice,
    this.status = CallStatus.ringing,
    required this.createdAt,
    this.endedAt,
    this.circleId,
  });

  bool get isGroupCall => circleId != null || receiverIds.length > 1;

  Map<String, dynamic> toMap() {
    return {
      'channelName': channelName,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverIds': receiverIds,
      'type': type.name,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      'endedAt': endedAt,
      'circleId': circleId,
    };
  }

  factory Call.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Call(
      id: doc.id,
      channelName: data['channelName'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callerPhoto: data['callerPhoto'] ?? '',
      receiverIds: List<String>.from(data['receiverIds'] ?? []),
      type: CallType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'voice'),
        orElse: () => CallType.voice,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'ringing'),
        orElse: () => CallStatus.ringing,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      circleId: data['circleId'],
    );
  }

  Call copyWith({CallStatus? status, DateTime? endedAt}) {
    return Call(
      id: id,
      channelName: channelName,
      callerId: callerId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      receiverIds: receiverIds,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      endedAt: endedAt ?? this.endedAt,
      circleId: circleId,
    );
  }
}
