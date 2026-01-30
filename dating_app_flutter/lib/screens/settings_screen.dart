import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../main.dart';

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
          _showOnlineStatus = settings['show_online_status'] ?? true;
          _showDistance = settings['show_distance'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    try {
      await apiService.updateSettings({key: value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка сохранения'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showBlockedUsers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _BlockedUsersSheet(),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text('Это действие необратимо. Все данные будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await apiService.deleteAccount();
                if (mounted) {
                  _goToWelcome();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ошибка удаления'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await apiService.logout();
              if (mounted) {
                _goToWelcome();
              }
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  void _goToWelcome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSection('Уведомления'),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications, color: Colors.blue),
                  title: const Text('Push-уведомления'),
                  value: _pushNotifications,
                  onChanged: (v) {
                    setState(() => _pushNotifications = v);
                    _updateSetting('push_notifications', v);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.message, color: Colors.green),
                  title: const Text('Новые сообщения'),
                  value: _messageNotifications,
                  onChanged: (v) {
                    setState(() => _messageNotifications = v);
                    _updateSetting('message_notifications', v);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.favorite, color: Colors.pink),
                  title: const Text('Новые матчи'),
                  value: _matchNotifications,
                  onChanged: (v) {
                    setState(() => _matchNotifications = v);
                    _updateSetting('match_notifications', v);
                  },
                ),
                const Divider(height: 32),
                _buildSection('Приватность'),
                SwitchListTile(
                  secondary: const Icon(Icons.circle, color: Colors.green),
                  title: const Text('Онлайн-статус'),
                  value: _showOnlineStatus,
                  onChanged: (v) {
                    setState(() => _showOnlineStatus = v);
                    _updateSetting('show_online_status', v);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.location_on, color: Colors.orange),
                  title: const Text('Показывать расстояние'),
                  value: _showDistance,
                  onChanged: (v) {
                    setState(() => _showDistance = v);
                    _updateSetting('show_distance', v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Заблокированные'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showBlockedUsers,
                ),
                const Divider(height: 32),
                _buildSection('Внешний вид'),
                SwitchListTile(
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.indigo : Colors.amber),
                  title: const Text('Тёмная тема'),
                  value: isDark,
                  onChanged: (_) => themeService.toggleTheme(),
                ),
                const Divider(height: 32),
                _buildSection('Аккаунт'),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.grey),
                  title: const Text('Выйти'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showLogoutDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showDeleteAccountDialog,
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSection(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
  );
}

class _BlockedUsersSheet extends StatefulWidget {
  const _BlockedUsersSheet();
  @override
  State<_BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends State<_BlockedUsersSheet> {
  List<dynamic> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _blocked = await apiService.getBlockedUsers();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _unblock(int id, String name) async {
    try {
      await apiService.unblockUser(id);
      setState(() => _blocked.removeWhere((u) => u['id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name разблокирован')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.5,
    expand: false,
    builder: (_, sc) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Заблокированные', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _blocked.isEmpty
                  ? const Center(child: Text('Список пуст'))
                  : ListView.builder(
                      controller: sc,
                      itemCount: _blocked.length,
                      itemBuilder: (_, i) {
                        final u = _blocked[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text(u['name']?[0] ?? '?')),
                          title: Text(u['name'] ?? ''),
                          trailing: TextButton(
                            onPressed: () => _unblock(u['id'], u['name'] ?? ''),
                            child: const Text('Разблокировать'),
                          ),
                        );
                      },
                    ),
        ),
      ],
    ),
  );
}
