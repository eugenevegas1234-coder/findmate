import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isLocationEnabled = true;
  DateTime? _lastUpdateTime;
  
  // Минимальный интервал между обновлениями (15 минут)
  static const int _updateIntervalMinutes = 15;
  
  // Минимальное расстояние для обновления (100 метров)
  static const double _minDistanceMeters = 100;

  Position? get currentPosition => _currentPosition;
  bool get isLocationEnabled => _isLocationEnabled;

  // Проверка и запрос разрешений
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Получение позиции с кэшированием
  Future<Position?> getCurrentPosition({bool forceUpdate = false}) async {
    if (!_isLocationEnabled) return null;

    // Проверяем, нужно ли обновлять
    if (!forceUpdate && !_shouldUpdate()) {
      return _currentPosition;
    }

    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return _currentPosition;

    try {
      // Сначала пробуем получить последнюю известную позицию (быстро, без GPS)
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      
      // Если есть кэшированная позиция и она свежая - используем её
      if (lastKnown != null && _isPositionFresh(lastKnown)) {
        _currentPosition = lastKnown;
        _lastUpdateTime = DateTime.now();
        await _saveLastPosition(lastKnown);
        return _currentPosition;
      }

      // Иначе получаем точную позицию (расходует батарею)
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Средняя точность экономит батарею
        timeLimit: const Duration(seconds: 10),
      );
      
      _lastUpdateTime = DateTime.now();
      await _saveLastPosition(_currentPosition!);
      
      return _currentPosition;
    } catch (e) {
      print('Ошибка получения геолокации: $e');
      // Возвращаем кэшированную позицию если есть
      return _currentPosition ?? await _loadLastPosition();
    }
  }

  // Проверка, нужно ли обновлять позицию
  bool _shouldUpdate() {
    if (_currentPosition == null) return true;
    if (_lastUpdateTime == null) return true;
    
    final minutesSinceUpdate = DateTime.now().difference(_lastUpdateTime!).inMinutes;
    return minutesSinceUpdate >= _updateIntervalMinutes;
  }

  // Проверка свежести позиции
  bool _isPositionFresh(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return age.inMinutes < _updateIntervalMinutes;
  }

  // Сохранение позиции в кэш
  Future<void> _saveLastPosition(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);
      await prefs.setInt('last_location_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Ошибка сохранения позиции: $e');
    }
  }

  // Загрузка позиции из кэша
  Future<Position?> _loadLastPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_latitude');
      final lon = prefs.getDouble('last_longitude');
      final time = prefs.getInt('last_location_time');
      
      if (lat != null && lon != null && time != null) {
        // Проверяем, не слишком ли старая позиция (макс 24 часа)
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(time)
        );
        if (age.inHours < 24) {
          return Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.fromMillisecondsSinceEpoch(time),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      }
    } catch (e) {
      print('Ошибка загрузки позиции: $e');
    }
    return null;
  }

  // Расчёт расстояния между двумя точками (в км)
  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  // Форматирование расстояния для отображения
  String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} м';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} км';
    } else {
      return '${distanceKm.round()} км';
    }
  }

  // Включить/выключить геолокацию
  void setLocationEnabled(bool enabled) {
    _isLocationEnabled = enabled;
    if (!enabled) {
      _currentPosition = null;
    }
  }

  // Принудительное обновление (для pull-to-refresh)
  Future<Position?> forceUpdatePosition() async {
    return getCurrentPosition(forceUpdate: true);
  }
}

final locationService = LocationService();
