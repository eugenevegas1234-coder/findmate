import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'websocket_service.dart';

class ApiService {
  static const String baseUrl = 'http://90.156.211.31:8000';

  String? _token;

  void setToken(String token) {
    _token = token;
    wsService.connect(token);
  }

  String getToken() {
    return _token ?? '';
  }

  // Сохранить токен локально
  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    wsService.connect(token);
  }

  // Загрузить токен из локального хранилища
  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null && _token!.isNotEmpty) {
      wsService.connect(_token!);
    }
    return _token;
  }

  // Очистить токен
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    wsService.disconnect();
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
    String? city,
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
        'city': city,
        'bio': bio,
        'interests': interests ?? [],
      }),
    );
    final data = jsonDecode(response.body);
    if (data['token'] != null) {
      await saveToken(data['token']);
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
      await saveToken(data['token']);
    }
    return data;
  }

  // Выход
  Future<void> logout() async {
    await clearToken();
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

  // ==================== ГЕОЛОКАЦИЯ ====================

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    bool showLocation = true,
  }) async {
    await http.put(
      Uri.parse('$baseUrl/location'),
      headers: _headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'show_location': showLocation,
      }),
    );
  }

  Future<Map<String, dynamic>> getLocationSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/location/settings'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  Future<void> updateLocationPrivacy(bool showLocation) async {
    await http.put(
      Uri.parse('$baseUrl/location/privacy?show_location=$showLocation'),
      headers: _headers,
    );
  }

  Future<List<dynamic>> getProfiles({double? maxDistance}) async {
    String url = '$baseUrl/profiles';
    if (maxDistance != null) {
      url += '?max_distance=$maxDistance';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // ==================== ЗАГРУЗКА ФОТО ====================

  Future<String> uploadProfilePhotoBytes(Uint8List bytes, String filename) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/photo'),
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
      return data['photo_url'];
    }
    throw Exception('Failed to upload photo: ${response.body}');
  }

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

  Future<void> deleteMessage(int userId, int messageId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/chat/$userId/message/$messageId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete message');
    }
  }

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

  // ==================== НАСТРОЙКИ ====================

  Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/settings'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    await http.put(
      Uri.parse('$baseUrl/settings'),
      headers: _headers,
      body: jsonEncode(settings),
    );
  }

  // ==================== БЛОКИРОВКА ====================

  Future<void> blockUser(int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/block/$userId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to block user');
    }
  }

  Future<void> unblockUser(int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/block/$userId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to unblock user');
    }
  }

  Future<List<dynamic>> getBlockedUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/blocked'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // ==================== ЖАЛОБЫ ====================

  Future<void> reportUser({
    required int userId,
    required String reason,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/report'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'reason': reason,
        'description': description,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to report user');
    }
  }

  // ==================== УДАЛЕНИЕ АККАУНТА ====================

  Future<void> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/account'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      await logout();
    } else {
      throw Exception('Failed to delete account');
    }
  }
}

final apiService = ApiService();
