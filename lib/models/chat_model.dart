import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, sent, read }

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final String text;
  final String? imageUrl; // For photo messages
  final String? replyToId; // ID of message being replied to
  final String? replyToText; // Preview of replied message
  final DateTime timestamp;
  final DateTime? readAt; // When message was read
  final MessageStatus status;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.text,
    this.imageUrl,
    this.replyToId,
    this.replyToText,
    required this.timestamp,
    this.readAt,
    this.status = MessageStatus.sent,
  });

  bool get isPhoto => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isReply => replyToId != null && replyToId!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'imageUrl': imageUrl,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'status': status.name,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderPhotoUrl: data['senderPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      replyToId: data['replyToId'],
      replyToText: data['replyToText'],
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      status: MessageStatus.values.firstWhere(
          (e) => e.name == (data['status'] ?? 'sent'),
          orElse: () => MessageStatus.sent),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
