import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ready_check/models/call_model.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';

class CallHistoryPage extends StatelessWidget {
  const CallHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Text(
                "Call Logs",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
            ),
            
            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('calls')
                    .where(Filter.or(
                      Filter('callerId', isEqualTo: uid),
                      Filter('receiverIds', arrayContains: uid),
                    ))
                    .orderBy('createdAt', descending: true)
                    .limit(50) 
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 60, color: Colors.grey.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            "No recent calls",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 120, left: 16, right: 16, top: 10),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      try {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final call = Call.fromFirestore(docs[index]);
                        final isOutgoing = call.callerId == uid;
                        
                        String title;
                        String subtitle;
                        IconData icon;
                        Color iconColor;

                        if (isOutgoing) {
                           title = call.isGroupCall ? "Group Call" : "Outgoing Call";
                           icon = Icons.call_made;
                           iconColor = Colors.greenAccent;
                        } else {
                           title = call.callerName.isNotEmpty ? call.callerName : "Unknown";
                           icon = call.status == CallStatus.missed ? Icons.call_missed : Icons.call_received;
                           iconColor = call.status == CallStatus.missed ? Colors.redAccent : Colors.blueAccent;
                        }

                        // Calculate Duration if ended
                        String durationStr = "";
                        if (call.endedAt != null) {
                            final duration = call.endedAt!.difference(call.createdAt);
                            final mins = duration.inMinutes;
                            final secs = duration.inSeconds % 60;
                            durationStr = " • ${mins}m ${secs}s";
                        } else if (call.status == CallStatus.ongoing) {
                            durationStr = " • Ongoing";
                            iconColor = Colors.orangeAccent;
                        } else if (call.status == CallStatus.missed || call.status == CallStatus.declined) {
                             // No duration
                        } else {
                             // Probably ended but endedAt not set (legacy or crash)
                             durationStr = ""; // Don't show
                        }

                        subtitle = DateFormat('MMM d, h:mm a').format(call.createdAt) + durationStr;

                        return GlassContainer(
                          opacity: 0.1,
                          blur: 5,
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                               Container(
                                 padding: const EdgeInsets.all(10),
                                 decoration: BoxDecoration(
                                   color: iconColor.withOpacity(0.1),
                                   shape: BoxShape.circle,
                                 ),
                                 child: Icon(icon, color: iconColor, size: 20),
                               ),
                               const SizedBox(width: 16),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                     const SizedBox(height: 4),
                                     Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                   ],
                                 ),
                               ),
                               if (call.status == CallStatus.missed)
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 16)
                            ],
                          ),
                        );
                      } catch (e) {
                         return const SizedBox.shrink();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
