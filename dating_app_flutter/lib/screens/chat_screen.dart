import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String? userPhoto;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isUploading = false;
  int? _myUserId;
  bool _isTyping = false;
  bool _partnerTyping = false;
  bool _partnerOnline = false;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _deleteSubscription;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadMyProfile();
    _loadPartnerStatus();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _messageSubscription = wsService.onMessage.listen((message) {
      if (message['sender_id'] == widget.userId ||
          message['receiver_id'] == widget.userId) {
        setState(() {
          bool exists = _messages.any((m) => m['id'] == message['id']);
          if (!exists) {
            _messages.add(message);
          }
        });
        _scrollToBottom();

        if (message['sender_id'] == widget.userId) {
          wsService.markAsRead(widget.userId);
        }
      }
    });

    _typingSubscription = wsService.onTyping.listen((data) {
      if (data['user_id'] == widget.userId) {
        setState(() {
          _partnerTyping = data['is_typing'];
        });
      }
    });

    _statusSubscription = wsService.onStatus.listen((data) {
      if (data['user_id'] == widget.userId) {
        setState(() {
          _partnerOnline = data['online'];
        });
      }
    });

    _deleteSubscription = wsService.onMessageDeleted.listen((data) {
      setState(() {
        _messages.removeWhere((m) => m['id'] == data['message_id']);
      });
    });
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await apiService.getProfile();
      setState(() {
        _myUserId = profile['id'];
      });
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadPartnerStatus() async {
    try {
      final status = await apiService.getUserStatus(widget.userId);
      setState(() {
        _partnerOnline = status['online'] ?? false;
      });
    } catch (e) {
      print('Error loading status: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await apiService.getMessages(widget.userId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
      wsService.markAsRead(widget.userId);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading messages: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      wsService.sendTyping(widget.userId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        wsService.sendTyping(widget.userId, false);
      }
    });
  }

  void _sendMessage({String? imageUrl}) {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    _messageController.clear();
    _isTyping = false;
    wsService.sendTyping(widget.userId, false);
    _typingTimer?.cancel();

    if (wsService.isConnected) {
      wsService.sendMessage(widget.userId, text, imageUrl: imageUrl);
    } else {
      _sendMessageHttp(text, imageUrl: imageUrl);
    }
  }

  Future<void> _sendMessageHttp(String text, {String? imageUrl}) async {
    try {
      final newMessage = await apiService.sendMessage(
        widget.userId,
        text,
        imageUrl: imageUrl,
      );
      setState(() {
        _messages.add(newMessage);
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки: $e')),
      );
    }
  }

  // Выбор и отправка фото
  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        // Читаем как bytes (работает и на веб, и на мобильных)
        final bytes = await image.readAsBytes();
        final filename = image.name;

        // Загружаем фото на сервер
        final imageUrl = await apiService.uploadChatPhotoBytes(
          widget.userId,
          bytes,
          filename,
        );

        setState(() {
          _isUploading = false;
        });

        // Отправляем сообщение с фото
        _sendMessage(imageUrl: imageUrl);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки фото: $e')),
      );
    }
  }

  // Удаление сообщения
  void _deleteMessage(dynamic message) {
    if (message['sender_id'] != _myUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Можно удалять только свои сообщения')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Сообщение будет удалено у вас и у собеседника'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete(message);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(dynamic message) async {
    try {
      if (wsService.isConnected) {
        wsService.deleteMessage(message['id'], widget.userId);
      } else {
        await apiService.deleteMessage(widget.userId, message['id']);
      }

      setState(() {
        _messages.removeWhere((m) => m['id'] == message['id']);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e')),
      );
    }
  }

  // Просмотр фото на весь экран
  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: apiService.getFullImageUrl(imageUrl),
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: widget.userPhoto != null
                  ? NetworkImage(apiService.getFullImageUrl(widget.userPhoto!))
                  : null,
              child: widget.userPhoto == null
                  ? Text(
                      widget.userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.userName),
                  Text(
                    _partnerTyping
                        ? 'печатает...'
                        : _partnerOnline
                            ? 'онлайн'
                            : 'не в сети',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: _partnerTyping || _partnerOnline
                          ? Colors.greenAccent
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.pinkAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет сообщений\nНапишите первым! 👋',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['sender_id'] == _myUserId;
                          final hasImage = message['image_url'] != null;

                          return GestureDetector(
                            onLongPress: () => _deleteMessage(message),
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.pinkAccent
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (hasImage)
                                      GestureDetector(
                                        onTap: () => _openFullScreenImage(
                                          message['image_url'],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(20),
                                          ),
                                          child: Image.network(
                                            apiService.getFullImageUrl(
                                              message['image_url'],
                                            ),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            loadingBuilder: (context, child, progress) {
                                              if (progress == null) return child;
                                              return Container(
                                                height: 150,
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stack) {
                                              return Container(
                                                height: 150,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.broken_image),
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                    if (message['text'] != null &&
                                        message['text'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        child: Text(
                                          message['text'],
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),

                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                        bottom: 8,
                                        top: hasImage && (message['text'] == null ||
                                            message['text'].toString().isEmpty) ? 8 : 0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatTime(message['timestamp']),
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white70
                                                  : Colors.black54,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              message['is_read'] == true
                                                  ? Icons.done_all
                                                  : Icons.done,
                                              size: 14,
                                              color: message['is_read'] == true
                                                  ? Colors.lightBlueAccent
                                                  : Colors.white70,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          if (_partnerTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypingDot(0),
                    _buildTypingDot(1),
                    _buildTypingDot(2),
                  ],
                ),
              ),
            ),

          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Загрузка фото...'),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.pinkAccent),
                  onPressed: _isUploading ? null : _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      hintText: 'Написать сообщение...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.pinkAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[600],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _statusSubscription?.cancel();
    _deleteSubscription?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
