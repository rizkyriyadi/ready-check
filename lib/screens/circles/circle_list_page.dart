import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ready_check/models/circle_model.dart';
import 'package:ready_check/services/circle_service.dart';
import 'package:ready_check/screens/circles/circle_detail_page.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CircleListPage extends StatelessWidget {
  const CircleListPage({super.key});

  void _showActionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Squad Actions"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
              title: const Text("Create New Circle"),
              onTap: () {
                Navigator.pop(context);
                _showCreateDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.login_rounded, color: Colors.green),
              title: const Text("Join Existing Circle"),
              onTap: () {
                Navigator.pop(context);
                _showJoinDialog(context);
              },
            ),
          ],
        ),
      )
    );
  }

  void _showCreateDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create New Circle"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Circle Name (e.g. Dota Weekend)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
           ElevatedButton(
             onPressed: () async {
                if (controller.text.isEmpty) return;
                Navigator.pop(context);
                final cs = Provider.of<CircleService>(context, listen: false);
                await cs.createCircle(controller.text);
             }, 
             child: const Text("Create")
           ),
        ]
      )
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Join Circle"),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: "Enter Code (e.g. A2B4C)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(context);
              final cs = Provider.of<CircleService>(context, listen: false);
              final success = await cs.joinCircle(controller.text);
              if (context.mounted) {
                if (success) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined!")));
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Code or Error.")));
                }
              }
            },
            child: const Text("Join"),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleService = Provider.of<CircleService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Circles", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120), // Increased to avoid Glass Navbar overlap
        child: FloatingActionButton.extended(
          onPressed: () => _showActionDialog(context),
          heroTag: 'circle_fab', // Unique tag
          icon: const Icon(Icons.group_add),
          label: const Text("New / Join"),
        ),
      ),
      body: StreamBuilder<List<Circle>>(
        stream: circleService.streamMyCircles(),
        builder: (context, snapshot) {
           if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
           if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

           final circles = snapshot.data!;
           if (circles.isEmpty) {
             return Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.diversity_3_outlined, size: 60, color: Colors.grey.shade300),
                   const SizedBox(height: 16),
                   const Text("No circles yet.\nCreate one to invite friends!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
                 ],
               ),
             );
           }

           return ListView.builder(
             padding: const EdgeInsets.all(16),
             itemCount: circles.length,
             itemBuilder: (context, index) {
               final circle = circles[index];
               return Card(
                 margin: const EdgeInsets.only(bottom: 12),
                 elevation: 2,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 child: ListTile(
                   contentPadding: const EdgeInsets.all(16),
                   leading: CircleAvatar(
                     radius: 25,
                     backgroundColor: Colors.primaries[index % Colors.primaries.length].shade100,
                     child: Text(circle.name[0].toUpperCase(), 
                        style: TextStyle(color: Colors.primaries[index % Colors.primaries.length].shade900, fontWeight: FontWeight.bold)),
                   ),
                   title: Text(circle.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   subtitle: Text("${circle.memberIds.length} Members"),
                   trailing: const Icon(Icons.chevron_right),
                   onTap: () {
                     Navigator.of(context).push(
                       MaterialPageRoute(builder: (_) => CircleDetailPage(circleId: circle.id, circleName: circle.name))
                     );
                   },
                 ),
               ).animate().fadeIn(delay: (50 * index).ms).slideX();
             },
           );
        },
      ),
    );
  }
}
