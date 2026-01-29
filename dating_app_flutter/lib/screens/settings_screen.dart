import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  
  const SettingsScreen({super.key, this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _messageNotifications = true;
  bool _matchNotifications = true;
  bool _showOnlineStatus = true;
  bool _showDistance = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await apiService.getSettings();
      if (mounted) {
        setState(() {
          _pushNotifications = settings['push_notifications'] ?? true;
          _messageNotifications = settings['message_notifications'] ?? true;
          _matchNotifications = settings['match_notifications'] ?? true;
          _showOnlineStatus = settings['show_online_status'] ??
