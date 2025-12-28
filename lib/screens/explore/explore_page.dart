import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/session_model.dart';
import 'package:ready_check/services/session_service.dart';
import 'package:ready_check/screens/session/ready_check_overlay.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mercenary Board", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Session>>(
        stream: sessionService.streamPublicSessions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final sessions = snapshot.data!;
          if (sessions.isEmpty) {
            return Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.public_off_outlined, size: 60, color: Colors.grey.shade300),
                   const SizedBox(height: 16),
                   const Text("No active sessions looking for players.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
                 ],
               ),
             );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final filled = session.participants.length;
              final total = session.requiredSlots;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                     // Join logic
                     showDialog(
                       context: context,
                       builder: (_) => AlertDialog(
                         title: const Text("Join Session?"),
                         content: Text("Join '${session.activityTitle}' as a Guest?"),
                         actions: [
                           TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Cancel")),
                           ElevatedButton(
                             onPressed: () async {
                               Navigator.pop(context);
                               final success = await sessionService.joinSession(session.id);
                               if (success && context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ReadyCheckOverlay(sessionId: session.id))
                                    // Actually better to open consistent overlay/screen.
                                  );
                               }
                             }, 
                             child: const Text("Join Squad")
                           ),
                         ],
                       )
                     );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           children: [
                             Expanded(
                               child: Text(session.activityTitle, 
                                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                               ),
                             ),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                               decoration: BoxDecoration(
                                 color: Colors.blue.shade50,
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: Colors.blue.shade100)
                               ),
                               child: Text("$filled/$total Filled", 
                                 style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)
                               ),
                             )
                           ],
                         ),
                         if (session.description.isNotEmpty) ...[
                           const SizedBox(height: 8),
                           Text(session.description, style: TextStyle(color: Colors.grey.shade600)),
                         ],
                         const SizedBox(height: 12),
                         Row(
                           children: [
                             const Icon(Icons.bolt, size: 16, color: Colors.amber),
                             const SizedBox(width: 4),
                             Text("Collecting Players...", style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontWeight: FontWeight.bold))
                           ],
                         )
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideY();
            },
          );
        },
      ),
    );
  }
}
