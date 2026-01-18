import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<dynamic> _profiles = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  double _dragX = 0;
  double _dragY = 0;
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final profiles = await apiService.getProfiles();
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

Future<void> _like() async {
  if (_currentIndex < _profiles.length) {
    final profile = _profiles[_currentIndex];
    final userId = profile['id'];

    try {
      final result = await apiService.likeUser(userId);
      
      // Отладка - смотрим что вернул сервер
      print('=== LIKE RESPONSE ===');
      print(result);
      print('is_match: ${result['is_match']}');
      print('=====================');

      if (result['is_match'] == true && mounted) {
        print('SHOWING MATCH DIALOG!');
        _showMatchDialog(profile);
      }
    } catch (e) {
      print('Like error: $e');
    }

    _nextProfile();
  }
}


  void _showMatchDialog(dynamic profile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.pink, Colors.deepOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉',
                style: TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 16),
              const Text(
                'Это матч!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Вы понравились ${profile['name']}!',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Продолжить',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.pink,
                    ),
                    child: const Text('Написать'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _skip() {
    if (_currentIndex < _profiles.length) {
      final userId = _profiles[_currentIndex]['id'];
      apiService.skipUser(userId);
      _nextProfile();
    }
  }

  void _nextProfile() {
    setState(() {
      _currentIndex++;
      _dragX = 0;
      _dragY = 0;
      _rotation = 0;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;
      _rotation = _dragX / 300 * 0.3;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragX > 100) {
      _animateAndLike();
    } else if (_dragX < -100) {
      _animateAndSkip();
    } else {
      setState(() {
        _dragX = 0;
        _dragY = 0;
        _rotation = 0;
      });
    }
  }

  void _animateAndLike() {
    setState(() {
      _dragX = 500;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      _like();
    });
  }

  void _animateAndSkip() {
    setState(() {
      _dragX = -500;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      _skip();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Пока нет пользователей', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_currentIndex >= _profiles.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Вы просмотрели всех!', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 0;
                });
                _loadProfiles();
              },
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
    }

    final profile = _profiles[_currentIndex];
    final commonInterests = List<String>.from(profile['common_interests'] ?? []);
    final allInterests = List<String>.from(profile['interests'] ?? []);
    final matchScore = profile['match_score'] ?? 0;
    final totalInterests = allInterests.length;
    final matchPercent = totalInterests > 0 ? (matchScore / totalInterests * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                transform: Matrix4.identity()
                  ..translate(_dragX, _dragY)
                  ..rotateZ(_rotation),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.pink, Colors.deepOrange],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.person, size: 40, color: Colors.white),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${profile['name']}, ${profile['age'] ?? '?'}',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (profile['city'] != null)
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 16, color: Colors.white70),
                                            const SizedBox(width: 4),
                                            Text(profile['city'], style: const TextStyle(color: Colors.white70)),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_currentIndex + 1}/${_profiles.length}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.favorite, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$matchPercent% совпадение',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (profile['bio'] != null && profile['bio'].toString().isNotEmpty)
                              Text(
                                profile['bio'],
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                maxLines: 3,
                              ),
                            const Spacer(),
                            const Text('Интересы:', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: allInterests.take(6).map((interest) {
                                final isCommon = commonInterests.contains(interest);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isCommon ? Colors.white : Colors.white24,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    interest,
                                    style: TextStyle(
                                      color: isCommon ? Colors.pink : Colors.white,
                                      fontWeight: isCommon ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_dragX > 50)
                      Positioned(
                        top: 50,
                        left: 30,
                        child: Transform.rotate(
                          angle: -0.3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'LIKE',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_dragX < -50)
                      Positioned(
                        top: 50,
                        right: 30,
                        child: Transform.rotate(
                          angle: 0.3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red, width: 3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'NOPE',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: _animateAndSkip,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 35, color: Colors.red),
                ),
              ),
              GestureDetector(
                onTap: _animateAndLike,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Colors.pink, Colors.red]),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite, size: 40, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
