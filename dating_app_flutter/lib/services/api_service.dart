import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'websocket_service.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  String? _token;

  void setToken(String token) {
    _token = token;
    wsService.connect(token);
  }

  String getToken() {
    return _token ?? '';
  }

  String getFullImageUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    return '$baseUrl$path';
  }

  Map<String, String> get _headers {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Map<String, String> get _authHeaders {
    Map<String, String> headers = {};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Регистрация
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    int? age,
    String? bio,
    List<String>? interests,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'age': age,
        'bio': bio,
        'interests': interests ?? [],
      }),
    );
    final data = jsonDecode(response.body);
    if (data['token'] != null) {
      _token = data['token'];
      wsService.connect(_token!);
    }
    return data;
  }

  // Вход
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    final data = jsonDecode(response.body);
    if (data['token'] != null) {
      _token = data['token'];
      wsService.connect(_token!);
    }
    return data;
  }

  // Выход
  void logout() {
    _token = null;
    wsService.disconnect();
  }

  // Получить профиль
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  // Обновить профиль
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/profile'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  // ==================== ЗАГРУЗКА ФОТО (WEB) ====================

  // Загрузить фото профиля из bytes (для веб)
  Future<String> uploadProfilePhotoBytes(Uint8List bytes, String filename) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/photo'),
    );
    request.headers.addAll(_authHeaders);
    
    // Определяем MIME тип
    String mimeType = 'image/jpeg';
    if (filename.toLowerCase().endsWith('.png')) {
      mimeType = 'image/png';
    } else if (filename.toLowerCase().endsWith('.gif')) {
      mimeType = 'image/gif';
    }
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType.parse(mimeType),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['photo_url'];
    }
    throw Exception('Failed to upload photo: ${response.body}');
  }

  // Загрузить фото в чат из bytes (для веб)
  Future<String> uploadChatPhotoBytes(int userId, Uint8List bytes, String filename) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/chat/$userId'),
    );
    request.headers.addAll(_authHeaders);
    
    String mimeType = 'image/jpeg';
    if (filename.toLowerCase().endsWith('.png')) {
      mimeType = 'image/png';
    } else if (filename.toLowerCase().endsWith('.gif')) {
      mimeType = 'image/gif';
    }
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType.parse(mimeType),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['image_url'];
    }
    throw Exception('Failed to upload chat photo: ${response.body}');
  }

  // Получить анкеты для просмотра
  Future<List<dynamic>> getProfiles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profiles'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // Лайкнуть пользователя
  Future<Map<String, dynamic>> likeUser(int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/like/$userId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'is_match': false};
  }

  // Пропустить пользователя
  Future<void> skipUser(int userId) async {
    await http.post(
      Uri.parse('$baseUrl/skip/$userId'),
      headers: _headers,
    );
  }

  // Получить матчи
  Future<List<dynamic>> getMatches() async {
    final response = await http.get(
      Uri.parse('$baseUrl/matches'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // ==================== ЧАТ ====================

  // Получить сообщения с пользователем
  Future<List<dynamic>> getMessages(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$userId/messages'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // Отправить сообщение
  Future<Map<String, dynamic>> sendMessage(
    int userId, 
    String text, {
    String? imageUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/$userId/send'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        'image_url': imageUrl,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to send message');
  }

  // Удалить сообщение
  Future<void> deleteMessage(int userId, int messageId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/chat/$userId/message/$messageId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete message');
    }
  }

  // Получить список диалогов
  Future<List<dynamic>> getChats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/chats'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // Получить статус пользователя
  Future<Map<String, dynamic>> getUserStatus(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/$userId/status'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'online': false};
  }
}

final apiService = ApiService();
