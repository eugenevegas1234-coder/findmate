import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

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
    final hasPermission = await locationService.checkAndRequestPermission();
    if (hasPermission) {
      final position = await locationService.getCurrentPosition();
      if (position != null) {
        setState(() => _locationEnabled = true);
        await apiService.updateLocation(latitude: position.latitude, longitude: position.longitude);
      }
    }
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final profiles = await apiService.getProfiles(maxDistance: _maxDistance);
      setState(() { _profiles = profiles; _currentIndex = 0; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
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
                const Text(
                  'Фильтр по расстоянию',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
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
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange[700]),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Включите геолокацию для фильтра по расстоянию',
                        style: TextStyle(fontSize: 13),
                      ),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.pink : Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : (_locationEnabled || distance == null ? Colors.black87 : Colors.grey),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
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
      } catch (e) { debugPrint('Like error'); }
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
    setState(() { _currentIndex++; _dragX = 0; _dragY = 0; _rotation = 0; });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() { _dragX += d.delta.dx; _dragY += d.delta.dy; _rotation = _dragX / 300 * 0.3; });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dragX > 100) _animateAndLike();
    else if (_dragX < -100) _animateAndSkip();
    else setState(() { _dragX = 0; _dragY = 0; _rotation = 0; });
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
                backgroundImage: hasPhoto ? NetworkImage(apiService.getFullImageUrl(profile['photo'])) : null,
                child: !hasPhoto ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
              ),
              const SizedBox(height: 16),
              const Text('Это матч!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Вы понравились $userName!', style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Продолжить', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (widget.onOpenChat != null) {
                        widget.onOpenChat!(userId: userId, userName: userName, userPhoto: userPhoto);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.pink),
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_profiles.isEmpty || _currentIndex >= _profiles.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _maxDistance != null 
                ? 'Нет людей в радиусе ${_maxDistance!.toInt()} км' 
                : 'Все просмотрено',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.tune),
                  label: Text(_getFilterLabel()),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () { setState(() => _currentIndex = 0); _loadProfiles(); },
                  child: const Text('Обновить'),
                ),
              ],
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
          // Filter button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_profiles.length - _currentIndex} профилей',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              GestureDetector(
                onTap: _showFilterDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _maxDistance != null ? Colors.pink[50] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border: _maxDistance != null ? Border.all(color: Colors.pink) : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 18,
                        color: _maxDistance != null ? Colors.pink : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getFilterLabel(),
                        style: TextStyle(
                          color: _maxDistance != null ? Colors.pink : Colors.grey[700],
                          fontWeight: _maxDistance != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                transform: Matrix4.identity()..translate(_dragX, _dragY)..rotateZ(_rotation),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        hasPhoto
                          ? Image.network(apiService.getFullImageUrl(profile['photo']), fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.pink[100], child: const Icon(Icons.person, size: 100, color: Colors.white)))
                          : Container(
                              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.pink, Colors.deepOrange])),
                              child: const Icon(Icons.person, size: 100, color: Colors.white54)),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.8)]),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$name, $age', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                                if (city != null || distance != null)
                                  Row(children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.white70),
                                    if (city != null) Text(' $city', style: const TextStyle(color: Colors.white70)),
                                    if (distance != null) Text(' • ${_formatDistance(distance)}', style: const TextStyle(color: Colors.white70)),
                                  ]),
                                if (interests.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, runSpacing: 6, children: interests.take(5).map((i) {
                                    final isCommon = commonInterests.contains(i);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: isCommon ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(12)),
                                      child: Text(i, style: TextStyle(color: isCommon ? Colors.pink : Colors.white, fontSize: 12)),
                                    );
                                  }).toList()),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_dragX > 50) Positioned(top: 50, left: 30, child: Container(
                          padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 3), borderRadius: BorderRadius.circular(10)),
                          child: const Text('LIKE', style: TextStyle(color: Colors.green, fontSize: 32, fontWeight: FontWeight.bold)))),
                        if (_dragX < -50) Positioned(top: 50, right: 30, child: Container(
                          padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 3), borderRadius: BorderRadius.circular(10)),
                          child: const Text('NOPE', style: TextStyle(color: Colors.red, fontSize: 32, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(onTap: _animateAndSkip, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10)]), child: const Icon(Icons.close, size: 35, color: Colors.red))),
              GestureDetector(onTap: _animateAndLike, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Colors.pink, Colors.red]), boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.4), blurRadius: 15)]), child: const Icon(Icons.favorite, size: 40, color: Colors.white))),
            ],
          ),
        ],
      ),
    );
  }
}
