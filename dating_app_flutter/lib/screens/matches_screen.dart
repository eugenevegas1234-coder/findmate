import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<dynamic> _matches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final matches = await apiService.getMatches();
      setState(() {
        _matches = matches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки матчей';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadMatches();
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_matches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Пока нет матчей',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Лайкайте анкеты - когда будет\nвзаимная симпатия, появится матч!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: ListView.builder(
        itemCount: _matches.length,
        itemBuilder: (context, index) {
          final match = _matches[index];
          final user = match['user'] ?? match;
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.pink[100],
                child: Text(
                  (user['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24, color: Colors.pink),
                ),
              ),
              title: Text(
                user['name'] ?? 'Пользователь',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                user['bio'] ?? 'Нет описания',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.chat, color: Colors.pink),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Чат скоро будет!')),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
