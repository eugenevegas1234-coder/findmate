import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  String? _token;

  void setToken(String token) {
    _token = token;
  }
  String getToken() {
    return _token ?? '';
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
    }
    return data;
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
}

final apiService = ApiService();
