import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  final Function({required int userId, required String userName, String? userPhoto})? onOpenChat;
  
  const MatchesScreen({super.key, this.onOpenChat});

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

  void _openChat(int userId, String userName, String? userPhoto) {
    if (widget.onOpenChat != null) {
      widget.onOpenChat!(userId: userId, userName: userName, userPhoto: userPhoto);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userId: userId,
            userName: userName,
            userPhoto: userPhoto,
          ),
        ),
      ).then((_) => _loadMatches());
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
          final lastMessage = match['last_message'];
          final hasPhoto = match['photo'] != null;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              onTap: () => _openChat(
                match['id'],
                match['name'] ?? 'Пользователь',
                match['photo'],
              ),
              leading: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.pink[100],
                backgroundImage: hasPhoto
                    ? NetworkImage(apiService.getFullImageUrl(match['photo']))
                    : null,
                child: !hasPhoto
                    ? Text(
                        (match['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24, color: Colors.pink),
                      )
                    : null,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      match['name'] ?? 'Пользователь',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (match['online'] == true)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              subtitle: Row(
                children: [
                  if (lastMessage != null && lastMessage['image_url'] != null)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.photo, size: 16, color: Colors.grey),
                    ),
                  Expanded(
                    child: Text(
                      lastMessage != null
                          ? (lastMessage['image_url'] != null &&
                                  (lastMessage['text'] == null ||
                                      lastMessage['text'].isEmpty))
                              ? 'Фото'
                              : lastMessage['text'] ?? ''
                          : 'Нажмите, чтобы начать чат',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: lastMessage != null ? Colors.black54 : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chat_bubble_outline, color: Colors.pink),
            ),
          );
        },
      ),
    );
  }
}
