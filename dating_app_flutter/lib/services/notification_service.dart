import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Счётчик непрочитанных сообщений
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  
  // Колбэк для показа уведомления
  Function(String title, String body, {int? userId, String? userName})? onNotification;

  // Показать уведомление о новом сообщении
  void showMessageNotification({
    required String senderName,
    required String message,
    int? senderId,
  }) {
    // Вибрация
    HapticFeedback.mediumImpact();
    
    // Увеличиваем счётчик
    unreadCount.value++;
    
    // Вызываем колбэк для показа UI
    if (onNotification != null) {
      onNotification!(
        senderName,
        message.length > 50 ? '${message.substring(0, 50)}...' : message,
        userId: senderId,
        userName: senderName,
      );
    }
  }

  // Показать уведомление о новом матче
  void showMatchNotification({
    required String userName,
    int? userId,
  }) {
    HapticFeedback.heavyImpact();
    
    if (onNotification != null) {
      onNotification!(
        'Новый матч! 💕',
        '$userName тоже проявил(а) интерес!',
        userId: userId,
        userName: userName,
      );
    }
  }

  // Сбросить счётчик непрочитанных
  void clearUnread() {
    unreadCount.value = 0;
  }

  // Уменьшить счётчик
  void decrementUnread() {
    if (unreadCount.value > 0) {
      unreadCount.value--;
    }
  }
}

final notificationService = NotificationService();
