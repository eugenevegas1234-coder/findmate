import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'notification_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  String? _token;
  bool _isConnected = false;
  
  // ID чата, который сейчас открыт (чтобы не показывать уведомления)
  int? _activeChatUserId;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _matchController = StreamController<Map<String, dynamic>>.broadcast();
  final _deleteController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onStatus => _statusController.stream;
  Stream<Map<String, dynamic>> get onMatch => _matchController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _deleteController.stream;

  bool get isConnected => _isConnected;

  // Установить активный чат (когда пользователь в чате)
  void setActiveChat(int? userId) {
    _activeChatUserId = userId;
  }

  void connect(String token) {
    if (_isConnected || _channel != null) {
      disconnect();
    }

    _token = token;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.1.104:8000/ws/$token'),
      );

      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data);
            _handleMessage(message);
          } catch (e) {
            print('WebSocket parse error: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _reconnect();
        },
        onDone: () {
          print('WebSocket closed');
          _isConnected = false;
          _reconnect();
        },
      );

      print('WebSocket connected with new token');
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'];

    switch (type) {
      case 'new_message':
        final msg = message['message'];
        _messageController.add(msg);
        
        // Показываем уведомление, если чат не открыт
        final senderId = msg['sender_id'];
        if (senderId != _activeChatUserId) {
          final senderName = msg['sender_name'] ?? 'Новое сообщение';
          final text = msg['text'] ?? '';
          final hasImage = msg['image_url'] != null;
          
          notificationService.showMessageNotification(
            senderName: senderName,
            message: hasImage && text.isEmpty ? '📷 Фото' : text,
            senderId: senderId,
          );
        }
        break;
        
      case 'message_sent':
        _messageController.add(message['message']);
        break;
        
      case 'typing':
        _typingController.add(message);
        break;
        
      case 'user_status':
        _statusController.add(message);
        break;
        
      case 'new_match':
        _matchController.add(message);
        // Показываем уведомление о новом матче
        final matchedUser = message['user'];
        if (matchedUser != null) {
          notificationService.showMatchNotification(
            userName: matchedUser['name'] ?? 'Кто-то',
            userId: matchedUser['id'],
          );
        }
        break;
        
      case 'message_deleted':
        _deleteController.add(message);
        break;
        
      case 'messages_read':
        break;
    }
  }

  void _reconnect() {
    if (_token != null && !_isConnected) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isConnected && _token != null) {
          print('Attempting to reconnect...');
          connect(_token!);
        }
      });
    }
  }

  void sendMessage(int receiverId, String text, {String? imageUrl}) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'receiver_id': receiverId,
      'text': text,
      'image_url': imageUrl,
    }));
  }

  void sendTyping(int receiverId, bool isTyping) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'typing',
      'receiver_id': receiverId,
      'is_typing': isTyping,
    }));
  }

  void markAsRead(int senderId) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'read',
      'sender_id': senderId,
    }));
  }

  void deleteMessage(int messageId, int partnerId) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'delete_message',
      'message_id': messageId,
      'partner_id': partnerId,
    }));
  }

  void disconnect() {
    print('WebSocket disconnecting...');
    _isConnected = false;
    _token = null;
    _activeChatUserId = null;
    try {
      _channel?.sink.close();
    } catch (e) {
      print('Error closing WebSocket: $e');
    }
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _statusController.close();
    _matchController.close();
    _deleteController.close();
  }
}

final wsService = WebSocketService();
