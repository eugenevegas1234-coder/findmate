import 'package:geolocator/geolocator.dart';
import 'dart:math';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isLocationEnabled = true;

  Position? get currentPosition => _currentPosition;
  bool get isLocationEnabled => _isLocationEnabled;

  // Проверка и запрос разрешений
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Проверяем включена ли геолокация
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Проверяем разрешения
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

  // Получение текущей позиции
  Future<Position?> getCurrentPosition() async {
    if (!_isLocationEnabled) return null;

    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (e) {
      print('Ошибка получения геолокации: $e');
      return null;
    }
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
}

final locationService = LocationService();
