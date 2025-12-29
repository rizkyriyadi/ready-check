import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ready_check/models/chat_model.dart';
import 'package:ready_check/services/direct_chat_service.dart';
import 'package:ready_check/services/call_service.dart';
import 'package:ready_check/screens/widgets/glass_container.dart';
import 'package:ready_check/screens/widgets/user_avatar.dart';
import 'package:ready_check/screens/widgets/mention_widgets.dart';
import 'package:ready_check/screens/widgets/photo_viewer.dart';
import 'package:ready_check/screens/call/voice_call_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DirectChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserPhoto;
  final String? otherUserId;

  const DirectChatPage({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserPhoto,
    this.otherUserId,
  });

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _typingTimer;
  bool _isTyping = false;
  
  // Reply state
  String? _replyToId;
  String? _replyToText;
  String? _replyToSender;
  
  // Store service reference for dispose
  late DirectChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = Provider.of<DirectChatService>(context, listen: false);
    _controller.addListener(_onTyping);
    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markAsRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTyping);
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _chatService.setTyping(widget.chatId, false);
    super.dispose();
  }

  void _onTyping() {
    if (_controller.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _chatService.setTyping(widget.chatId, true);
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _chatService.setTyping(widget.chatId, false);
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
    final chatService = Provider.of<DirectChatService>(context, listen: false);
    
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );
    
    if (image != null) {
      await chatService.sendPhoto(
        widget.chatId, 
        File(image.path),
        replyToId: _replyToId,
        replyToText: _replyToText,
      );
      _clearReply();
    }
  }

  Future<void> _takeAndSendPhoto() async {
    final chatService = Provider.of<DirectChatService>(context, listen: false);
    
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    
    if (image != null) {
      await chatService.sendPhoto(
        widget.chatId, 
        File(image.path),
        replyToId: _replyToId,
        replyToText: _replyToText,
      );
      _clearReply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<DirectChatService>(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            UserAvatar(photoUrl: widget.otherUserPhoto, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  // Typing indicator in app bar
                  StreamBuilder<bool>(
                    stream: chatService.streamTypingStatus(widget.chatId),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return const Text(
                          'typing...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.greenAccent,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.greenAccent),
            onPressed: () async {
              final callService = Provider.of<CallService>(context, listen: false);
              if (widget.otherUserId == null) return;
              final callId = await callService.startCall(receiverIds: [widget.otherUserId!]);
              if (callId != null && mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VoiceCallPage(
                      callId: callId,
                      isOutgoing: true,
                      otherUserName: widget.otherUserName,
                      otherUserPhoto: widget.otherUserPhoto,
                    ),
                  ),
                );
              }
            },
            tooltip: 'Voice Call',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: chatService.streamMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hi! 👋',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                // Mark as read when messages load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  chatService.markAsRead(widget.chatId);
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUid;

                    return GestureDetector(
                      onDoubleTap: () => _setReply(msg),
                      child: _buildMessageBubble(msg, isMe),
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
                      color: Colors.greenAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyToSender ?? '',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _replyToText ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _clearReply,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),

          // Input
          GlassContainer(
            opacity: 0.3,
            borderRadius: BorderRadius.zero,
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                // Photo buttons
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.grey),
                  onPressed: _pickAndSendImage,
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.grey),
                  onPressed: _takeAndSendPhoto,
                ),
                // Text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(chatService),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent),
                  onPressed: () => _sendMessage(chatService),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            UserAvatar(photoUrl: msg.senderPhotoUrl, radius: 14),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe 
                    ? Colors.greenAccent.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply preview
                  if (msg.isReply) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(color: Colors.greenAccent, width: 3),
                        ),
                      ),
                      child: Text(
                        msg.replyToText ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  // Image - tappable for full view
                  if (msg.isPhoto && msg.imageUrl != null) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PhotoViewerPage(
                              imageUrl: msg.imageUrl!,
                              senderName: msg.senderName,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          msg.imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 200,
                              height: 150,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Text - with @mention highlighting
                  if (msg.text.isNotEmpty && !msg.isPhoto)
                    MentionText(
                      text: msg.text,
                      style: TextStyle(
                        color: isMe ? Colors.greenAccent.shade100 : Colors.white,
                      ),
                      mentionStyle: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  // Read status for sent messages
                  if (isMe) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          msg.status == MessageStatus.read 
                              ? Icons.done_all 
                              : Icons.done,
                          size: 14,
                          color: msg.status == MessageStatus.read 
                              ? Colors.blue 
                              : Colors.grey.shade500,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _sendMessage(DirectChatService service) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _isTyping = false;
    service.setTyping(widget.chatId, false);
    
    await service.sendMessage(
      widget.chatId, 
      text,
      replyToId: _replyToId,
      replyToText: _replyToText,
    );
    
    _clearReply();
  }
}
