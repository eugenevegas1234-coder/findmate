import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  String? _token;
  bool _isConnected = false;

  // Контроллеры для разных событий
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _matchController = StreamController<Map<String, dynamic>>.broadcast();
  final _deleteController = StreamController<Map<String, dynamic>>.broadcast();

  // Стримы для подписки
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onStatus => _statusController.stream;
  Stream<Map<String, dynamic>> get onMatch => _matchController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _deleteController.stream;

  bool get isConnected => _isConnected;

  // Подключиться к WebSocket
  void connect(String token) {
    if (_isConnected) return;

    _token = token;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/ws/$token'),
      );

      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          final message = jsonDecode(data);
          _handleMessage(message);
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

      print('WebSocket connected');
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
    }
  }

  // Обработка входящих сообщений
  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'];

    switch (type) {
      case 'new_message':
        _messageController.add(message['message']);
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
        break;
      case 'message_deleted':
        _deleteController.add(message);
        break;
      case 'messages_read':
        // Можно добавить обработку
        break;
    }
  }

  // Переподключение
  void _reconnect() {
    if (_token != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isConnected) {
          connect(_token!);
        }
      });
    }
  }

  // Отправить сообщение
  void sendMessage(int receiverId, String text, {String? imageUrl}) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'receiver_id': receiverId,
      'text': text,
      'image_url': imageUrl,
    }));
  }

  // Отправить статус "печатает"
  void sendTyping(int receiverId, bool isTyping) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'typing',
      'receiver_id': receiverId,
      'is_typing': isTyping,
    }));
  }

  // Отметить сообщения как прочитанные
  void markAsRead(int senderId) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'read',
      'sender_id': senderId,
    }));
  }

  // Удалить сообщение
  void deleteMessage(int messageId, int partnerId) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'delete_message',
      'message_id': messageId,
      'partner_id': partnerId,
    }));
  }

  // Отключиться
  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }

  // Закрыть все стримы
  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _statusController.close();
    _matchController.close();
    _deleteController.close();
  }
}

// Глобальный экземпляр
final wsService = WebSocketService();
