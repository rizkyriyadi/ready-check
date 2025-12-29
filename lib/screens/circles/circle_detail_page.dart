import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:ready_check/models/circle_model.dart';
import 'package:ready_check/services/circle_service.dart';
import 'package:ready_check/services/auth_service.dart';
import 'package:ready_check/services/session_service.dart';
import 'package:ready_check/screens/session/ready_check_overlay.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/mention_widgets.dart';
import 'package:ready_check/screens/friends/user_profile_page.dart';
import 'package:ready_check/screens/circles/circle_settings_page.dart';
import 'package:intl/intl.dart';

class CircleDetailPage extends StatefulWidget {
  final String circleId;
  final String circleName;

  const CircleDetailPage({super.key, required this.circleId, required this.circleName});

  @override
  State<CircleDetailPage> createState() => _CircleDetailPageState();
}

class _CircleDetailPageState extends State<CircleDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _typingTimer;
  bool _isTyping = false;
  
  // Reply state
  String? _replyToId;
  String? _replyToText;
  String? _replyToSender;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTyping);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTyping);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    final circleService = Provider.of<CircleService>(context, listen: false);
    circleService.setTyping(widget.circleId, false);
    super.dispose();
  }

  void _onTyping() {
    final circleService = Provider.of<CircleService>(context, listen: false);
    
    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      circleService.setTyping(widget.circleId, true);
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        circleService.setTyping(widget.circleId, false);
      }
    });
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToText = null;
      _replyToSender = null;
    });
  }

  void _setReply(Message msg) {
    setState(() {
      _replyToId = msg.id;
      _replyToText = msg.text.length > 50 ? '${msg.text.substring(0, 50)}...' : msg.text;
      _replyToSender = msg.senderName;
    });
  }

  Future<void> _pickAndSendImage() async {
    final circleService = Provider.of<CircleService>(context, listen: false);
    
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );
    
    if (image != null) {
      await circleService.sendPhoto(
        widget.circleId, 
        File(image.path),
        replyToId: _replyToId,
        replyToText: _replyToText,
      );
      _clearReply();
    }
  }

  Future<void> _takeAndSendPhoto() async {
    final circleService = Provider.of<CircleService>(context, listen: false);
    
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    
    if (image != null) {
      await circleService.sendPhoto(
        widget.circleId, 
        File(image.path),
        replyToId: _replyToId,
        replyToText: _replyToText,
      );
      _clearReply();
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    final circleService = Provider.of<CircleService>(context, listen: false);
    circleService.sendCircleMessage(
      widget.circleId, 
      _messageController.text,
      replyToId: _replyToId,
      replyToText: _replyToText,
    );
    _messageController.clear();
    _isTyping = false;
    _clearReply();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _triggerSummon() async {
     final sessionService = Provider.of<SessionService>(context, listen: false);
     final sessionId = await sessionService.createSession(
       circleId: widget.circleId,
       activityTitle: "${widget.circleName} Raid",
       requiredSlots: 5,
       isPublic: true
     );
     
     if (sessionId != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReadyCheckOverlay(sessionId: sessionId))
        );
        final circleService = Provider.of<CircleService>(context, listen: false);
        circleService.sendCircleMessage(widget.circleId, "SUMMONED THE SQUAD! JOIN NOW!");
     }
  }
  
  void _showInviteCode(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(widget.circleName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Invite Code:"),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text("Share this code with friends.", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Close"))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleService = Provider.of<CircleService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.user?.uid;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: GlassContainer(
          borderRadius: BorderRadius.zero,
          blur: 10, 
          opacity: 0.2,
          child: Container(),
        ),
        title: StreamBuilder<Circle>(
          stream: circleService.streamCircle(widget.circleId),
          builder: (context, snapshot) {
            final circle = snapshot.data;
            return Row(
              children: [
                if (circle != null && circle.photoUrl.isNotEmpty)
                  UserAvatar(photoUrl: circle.photoUrl, radius: 18)
                else
                  CircleAvatar(radius: 18, backgroundColor: theme.colorScheme.primary.withOpacity(0.3), child: const Icon(Icons.group, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(circle?.name ?? widget.circleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      // Typing indicator
                      StreamBuilder<List<String>>(
                        stream: circleService.streamTypingMembers(widget.circleId),
                        builder: (context, typingSnap) {
                          final typingNames = typingSnap.data ?? [];
                          if (typingNames.isEmpty) return const SizedBox.shrink();
                          final text = typingNames.length == 1 
                              ? '${typingNames.first} is typing...'
                              : '${typingNames.length} people typing...';
                          return Text(
                            text,
                            style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontStyle: FontStyle.italic),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: _triggerSummon,
            icon: const Icon(Icons.bolt, color: Colors.amberAccent),
            tooltip: "Summon Squad",
          ),
          StreamBuilder<Circle>(
            stream: circleService.streamCircle(widget.circleId),
            builder: (context, snapshot) {
              final code = snapshot.data?.code ?? '...';
              return IconButton(
                icon: const Icon(Icons.info_outline), 
                onPressed: () => _showInviteCode(code),
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CircleSettingsPage(circleId: widget.circleId),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
           gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.brightness == Brightness.dark 
                 ? [const Color(0xFF111827), const Color(0xFF1F2937)]
                 : [const Color(0xFFF9FAFB), const Color(0xFFF3F4F6)]
           )
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: circleService.streamCircleMessages(widget.circleId),
                builder: (context, snapshot) {
                   if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                   final messages = snapshot.data!;
                   if (messages.isEmpty) return Center(child: Text("Say hi to the squad!", style: TextStyle(color: theme.hintColor)));
  
                   return ListView.builder(
                     controller: _scrollController,
                     reverse: true,
                     padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
                     itemCount: messages.length,
                     itemBuilder: (context, index) {
                       final msg = messages[index];
                       final isMe = msg.senderId == currentUserId;
                       return GestureDetector(
                         onDoubleTap: () => _setReply(msg),
                         child: _CircleMessageBubble(message: msg, isMe: isMe),
                       );
                     },
                   );
                },
              ),
            ),

            // Reply preview
            if (_replyToId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white.withOpacity(0.05),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_replyToSender ?? '', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(_replyToText ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearReply, color: Colors.grey),
                  ],
                ),
              ),
            
            // Input Area
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GlassContainer(
                  blur: 10,
                  opacity: theme.brightness == Brightness.dark ? 0.3 : 0.6,
                  color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.photo, color: Colors.grey),
                          onPressed: _pickAndSendImage,
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.grey),
                          onPressed: _takeAndSendPhoto,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                            decoration: InputDecoration(
                              hintText: "Message...",
                              hintStyle: TextStyle(color: theme.hintColor),
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        IconButton(
                          onPressed: _sendMessage, 
                          icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _CircleMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _CircleMessageBubble({required this.message, required this.isMe});
  
  void _showUserProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(userId: message.senderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // System Message Check
    if (message.text.contains("SUMMONED THE SQUAD")) {
       return Center(
         child: Container(
           margin: const EdgeInsets.symmetric(vertical: 12),
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           decoration: BoxDecoration(
             color: Colors.amber.withOpacity(0.1), 
             borderRadius: BorderRadius.circular(16), 
             border: Border.all(color: Colors.amber)
           ),
           child: Text("⚡ ${message.senderName} SUMMONED THE SQUAD!", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
         ),
       );
    }

    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => _showUserProfile(context),
              child: UserAvatar(photoUrl: message.senderPhotoUrl, radius: 16),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                 if (!isMe) ...[
                   GestureDetector(
                     onTap: () => _showUserProfile(context),
                     child: Padding(
                       padding: const EdgeInsets.only(bottom: 4, left: 4),
                       child: Text(message.senderName, style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                     ),
                   )
                 ],
                 Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? theme.colorScheme.primary.withOpacity(0.2) : theme.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: !isMe ? const Radius.circular(20) : const Radius.circular(4),
                    ),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Reply preview
                      if (message.isReply) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
                          ),
                          child: Text(message.replyToText ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                        ),
                      ],
                      // Image
                      if (message.isPhoto && message.imageUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message.imageUrl!,
                            width: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator()));
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      // Text (only if not photo-only) - with mention highlighting
                      if (!message.isPhoto)
                        MentionText(
                          text: message.text,
                          style: TextStyle(fontSize: 15, color: theme.textTheme.bodyLarge?.color),
                          mentionStyle: const TextStyle(fontSize: 15, color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(timeStr, style: TextStyle(fontSize: 9, color: theme.textTheme.bodySmall?.color)),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                               message.status == MessageStatus.read ? Icons.done_all : Icons.check, 
                               size: 12, 
                               color: message.status == MessageStatus.read ? Colors.blue : Colors.grey
                            )
                          ]
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (isMe) const SizedBox(width: 48),
        ],
      ),
    );
  }
}
