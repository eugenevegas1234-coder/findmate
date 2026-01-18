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

        if (result['is_match'] == true && mounted) {
          _showMatchDialog(profile);
        }
      } catch (e) {
        print('Like error: $e');
      }

      _nextProfile();
    }
  }

  void _showMatchDialog(dynamic profile) {
    final hasPhoto = profile['photo'] != null;
    
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
              // Фото в диалоге матча
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white24,
                backgroundImage: hasPhoto
                    ? NetworkImage(apiService.getFullImageUrl(profile['photo']))
                    : null,
                child: !hasPhoto
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
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
    final hasPhoto = profile['photo'] != null;

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
                    // Карточка с фото на фоне
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Фото или градиент
                            if (hasPhoto)
                              Image.network(
                                apiService.getFullImageUrl(profile['photo']),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) {
                                  return Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.pink, Colors.deepOrange],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.person, size: 100, color: Colors.white54),
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.pink, Colors.deepOrange],
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(Icons.person, size: 100, color: Colors.white54),
                                ),
                              ),
                            
                            // Затемнение снизу для текста
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 250,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Информация о пользователе
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Имя и возраст
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${profile['name']}, ${profile['age'] ?? '?'}',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        // Счётчик
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
                                    
                                    // Город
                                    if (profile['city'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Text(
                                            profile['city'],
                                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 12),
                                    
                                    // Процент совпадения
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.pink,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.favorite, color: Colors.white, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$matchPercent% совпадение',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Описание
                                    if (profile['bio'] != null && profile['bio'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        profile['bio'],
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    
                                    // Интересы
                                    if (allInterests.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: allInterests.take(5).map((interest) {
                                          final isCommon = commonInterests.contains(interest);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isCommon ? Colors.white : Colors.white24,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              interest,
                                              style: TextStyle(
                                                color: isCommon ? Colors.pink : Colors.white,
                                                fontSize: 12,
                                                fontWeight: isCommon ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // LIKE индикатор
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
                    
                    // NOPE индикатор
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
          
          // Кнопки
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
