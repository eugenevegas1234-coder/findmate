import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/page_transitions.dart';
import 'user_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final Function({required int userId, required String userName, String? userPhoto})? onOpenChat;
  const DiscoverScreen({super.key, this.onOpenChat});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<dynamic> _profiles = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _locationEnabled = false;
  double _dragX = 0;
  double _dragY = 0;
  double _rotation = 0;
  double? _maxDistance;

  final List<double?> _distanceOptions = [null, 5, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final hasPermission = await locationService.checkAndRequestPermission();
      if (hasPermission) {
        final position = await locationService.getCurrentPosition();
        if (position != null && mounted) {
          setState(() => _locationEnabled = true);
          await apiService.updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
    if (mounted) _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final profiles = await apiService.getProfiles(maxDistance: _maxDistance);
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _currentIndex = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openUserProfile(Map<String, dynamic> profile) {
    Navigator.push(
      context,
      SlideUpRoute(
        page: UserProfileScreen(
          user: profile,
          onLike: _like,
          onDislike: _skip,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Фильтр по расстоянию',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_locationEnabled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange[900] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange[700]),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Включите геолокацию для фильтра',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _distanceOptions.map((distance) {
                final isSelected = _maxDistance == distance;
                final label = distance == null ? 'Все' : '${distance.toInt()} км';
                return GestureDetector(
                  onTap: _locationEnabled || distance == null
                      ? () {
                          setState(() => _maxDistance = distance);
                          Navigator.pop(ctx);
                          _loadProfiles();
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.pink 
                          : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _like() async {
    if (_currentIndex < _profiles.length) {
      final profile = _profiles[_currentIndex];
      try {
        final result = await apiService.likeUser(profile['id']);
        if (result['is_match'] == true && mounted) _showMatchDialog(profile);
      } catch (e) {
        debugPrint('Like error');
      }
      _nextProfile();
    }
  }

  void _skip() {
    if (_currentIndex < _profiles.length) {
      apiService.skipUser(_profiles[_currentIndex]['id']);
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

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _dragX += d.delta.dx;
      _dragY += d.delta.dy;
      _rotation = _dragX / 300 * 0.3;
    });
  }

  void _onPanEnd(DragEndDetails d) {
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
    setState(() => _dragX = 500);
    Future.delayed(const Duration(milliseconds: 200), _like);
  }

  void _animateAndSkip() {
    setState(() => _dragX = -500);
    Future.delayed(const Duration(milliseconds: 200), _skip);
  }

  void _showMatchDialog(dynamic profile) {
    final hasPhoto = profile['photo'] != null;
    final userId = profile['id'] as int;
    final userName = (profile['name'] ?? 'Пользователь') as String;
    final userPhoto = profile['photo'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.pink, Colors.deepOrange]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 60, color: Colors.white),
              const SizedBox(height: 16),
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
              const Text('Это матч!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Вы понравились $userName!',
                  style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Продолжить',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (widget.onOpenChat != null) {
                        widget.onOpenChat!(
                            userId: userId, userName: userName, userPhoto: userPhoto);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.pink),
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

  String _formatDistance(double? d) {
    if (d == null) return '';
    if (d < 1) return '${(d * 1000).round()} м';
    if (d < 10) return '${d.toStringAsFixed(1)} км';
    return '${d.round()} км';
  }

  String _getFilterLabel() {
    if (_maxDistance == null) return 'Все';
    return '${_maxDistance!.toInt()} км';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_profiles.isEmpty || _currentIndex >= _profiles.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, 
                color: isDark ? Colors.grey[600] : Colors.grey),
            const SizedBox(height: 16),
            Text(
              _maxDistance != null
                  ? 'Нет людей в радиусе ${_maxDistance!.toInt()} км'
                  : 'Анкеты закончились',
              style: TextStyle(fontSize: 18, 
                  color: isDark ? Colors.grey[400] : Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadProfiles,
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
    }

    final profile = _profiles[_currentIndex];
    final hasPhoto = profile['photo'] != null;
    final distance = profile['distance'] as double?;
    final interests = List<String>.from(profile['interests'] ?? []);
    final commonInterests = List<String>.from(profile['common_interests'] ?? []);
    final name = profile['name'] ?? '???';
    final age = profile['age'] ?? '?';
    final city = profile['city'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Верхняя панель
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_profiles.length - _currentIndex} профилей',
                  style: TextStyle(color: Colors.grey[600])),
              GestureDetector(
                onTap: _showFilterDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _maxDistance != null 
                        ? (isDark ? Colors.pink[900] : Colors.pink[50])
                        : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 18,
                          color: _maxDistance != null ? Colors.pink : Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(_getFilterLabel(),
                          style: TextStyle(
                              color: _maxDistance != null ? Colors.pink : Colors.grey[700])),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Карточка профиля
          Expanded(
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTap: () => _openUserProfile(Map<String, dynamic>.from(profile)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                transform: Matrix4.identity()
                  ..translate(_dragX, _dragY)
                  ..rotateZ(_rotation),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.pink.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Фото с Hero-анимацией
                        Hero(
                          tag: 'user_photo_${profile['id']}',
                          child: hasPhoto
                              ? Image.network(
                                  apiService.getFullImageUrl(profile['photo']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                      color: Colors.pink[100],
                                      child: const Icon(Icons.person,
                                          size: 100, color: Colors.white)))
                              : Container(
                                  decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: [Colors.pink, Colors.deepOrange])),
                                  child: const Icon(Icons.person,
                                      size: 100, color: Colors.white54)),
                        ),
                        
                        // Информация внизу
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.8)
                                  ]),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('$name, $age',
                                          style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                    ),
                                    // Кнопка "подробнее"
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.info_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                if (city != null || distance != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(children: [
                                      const Icon(Icons.location_on,
                                          size: 16, color: Colors.white70),
                                      if (city != null)
                                        Text(' $city',
                                            style:
                                                const TextStyle(color: Colors.white70)),
                                      if (distance != null)
                                        Text(' • ${_formatDistance(distance)}',
                                            style:
                                                const TextStyle(color: Colors.white70)),
                                    ]),
                                  ),
                                if (interests.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: interests.take(5).map((i) {
                                        final isCommon = commonInterests.contains(i);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: isCommon
                                                  ? Colors.white
                                                  : Colors.white24,
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Text(i,
                                              style: TextStyle(
                                                  color: isCommon
                                                      ? Colors.pink
                                                      : Colors.white,
                                                  fontSize: 12)),
                                        );
                                      }).toList()),
                                ],
                                // Подсказка
                                const SizedBox(height: 8),
                                Text(
                                  'Нажмите для подробностей',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
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
                              child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      border: Border.all(color: Colors.green, width: 3),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Text('LIKE',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold)))),
                        
                        // NOPE индикатор
                        if (_dragX < -50)
                          Positioned(
                              top: 50,
                              right: 30,
                              child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      border: Border.all(color: Colors.red, width: 3),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Text('NOPE',
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Кнопки действий
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Пропустить
              _ActionButton(
                icon: Icons.close,
                color: Colors.red,
                onTap: _animateAndSkip,
              ),
              // Лайк
              _ActionButton(
                icon: Icons.favorite,
                color: Colors.pink,
                isMain: true,
                onTap: _animateAndLike,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isMain;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.isMain = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = isMain ? 80.0 : 70.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isMain ? null : (isDark ? Colors.grey[800] : Colors.white),
          gradient: isMain
              ? const LinearGradient(colors: [Colors.pink, Colors.red])
              : null,
          boxShadow: [
            BoxShadow(
              color: (isMain ? Colors.pink : Colors.grey).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: isMain ? 40 : 35,
          color: isMain ? Colors.white : color,
        ),
      ),
    );
  }
}
