import 'package:flutter/material.dart';
import 'package:ready_check/services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  
  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _statusText = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.greenAccent, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'New Update Available! 🚀',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.updateInfo.currentVersion,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  Text(
                    widget.updateInfo.latestVersion,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Release notes
            Text(
              widget.updateInfo.releaseNotes,
              style: TextStyle(color: Colors.grey.shade300),
            ),
            
            if (widget.updateInfo.changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'What\'s New:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...widget.updateInfo.changelog.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              )),
            ],

            // Download progress
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.shade800,
                valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _statusText.isEmpty 
                      ? '${(_progress * 100).toInt()}%'
                      : _statusText,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: widget.updateInfo.forceUpdate 
                ? null 
                : () => Navigator.of(context).pop(),
            child: Text(
              'Later',
              style: TextStyle(
                color: widget.updateInfo.forceUpdate 
                    ? Colors.grey.shade600 
                    : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _startDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Update Now'),
          ),
        ] else
          const SizedBox.shrink(),
      ],
    );
  }

  void _startDownload() async {
    if (widget.updateInfo.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download URL not available')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusText = 'Downloading...';
    });

    final updateService = UpdateService();
    final success = await updateService.downloadAndInstall(
      widget.updateInfo.downloadUrl,
      (progress) {
        setState(() {
          _progress = progress;
          if (progress >= 1.0) {
            _statusText = 'Installing...';
          }
        });
      },
    );

    if (!success && mounted) {
      setState(() {
        _isDownloading = false;
        _statusText = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed. Please try again.')),
      );
    }
  }
}

/// Helper function to show update dialog
Future<void> showUpdateDialog(BuildContext context, UpdateInfo updateInfo) async {
  await showDialog(
    context: context,
    barrierDismissible: !updateInfo.forceUpdate,
    builder: (context) => UpdateDialog(updateInfo: updateInfo),
  );
}
