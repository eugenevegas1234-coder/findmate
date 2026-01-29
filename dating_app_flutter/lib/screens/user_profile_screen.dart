import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class UserProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;

  const UserProfileScreen({
    super.key,
    required this.user,
    this.onLike,
    this.onDislike,
  });

  void _showReportDialog(BuildContext context) {
    final reasons = [
      {'id': 'fake', 'title': 'Фейковый профиль', 'icon': Icons.person_off},
      {'id': 'spam', 'title': 'Спам / Реклама', 'icon': Icons.campaign},
      {'id': 'offensive', 'title': 'Оскорбительный контент', 'icon': Icons.warning},
      {'id': 'inappropriate', 'title': 'Неприемлемые фото', 'icon': Icons.image_not_supported},
      {'id': 'harassment', 'title': 'Домогательства', 'icon': Icons.front_hand},
      {'id': 'other', 'title': 'Другое', 'icon': Icons.more_horiz},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              children: [
                const Icon(Icons.flag, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Пожаловаться',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Почему вы хотите пожаловаться на ${user['name']}?',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...reasons.map((reason) => ListTile(
              leading: Icon(reason['icon'] as IconData, color: Colors.grey[700]),
              title: Text(reason['title'] as String),
              onTap: () {
                Navigator.pop(ctx);
                _submitReport(context, reason['id'] as String, reason['title'] as String);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport(BuildContext context, String reasonId, String reasonTitle) async {
    final descController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Жалоба: $reasonTitle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Добавьте описание (необязательно):'),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Опишите проблему...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await apiService.reportUser(
          userId: user['id'],
          reason: reasonId,
          description: descController.text.isNotEmpty ? descController.text : null,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Жалоба отправлена. Спасибо!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка отправки жалобы'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заблокировать пользователя?'),
        content: Text(
          '${user['name']} не сможет видеть ваш профиль и писать вам сообщения.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await apiService.blockUser(user['id']);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Пользователь заблокирован'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.pop(context); // Закрыть профиль
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка блокировки'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Пожаловаться'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Заблокировать'),
              onTap: () {
                Navigator.pop(ctx);
                _showBlockDialog(context);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Отмена'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = user['photo'] != null;
    final interests = user['interests'] as List<dynamic>? ?? [];
    final commonInterests = user['common_interests'] as List<dynamic>? ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Фото с кнопками
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showMoreOptions(context),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'user_photo_${user['id']}',
                child: hasPhoto
                    ? Image.network(
                        apiService.getFullImageUrl(user['photo']),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
          ),

          // Контент
          SliverToBoxAdapter(
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
                          '${user['name'] ?? 'Без имени'}, ${user['age'] ?? '?'}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (user['is_online'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Онлайн',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Город и расстояние
                  Row(
                    children: [
                      if (user['city'] != null) ...[
                        Icon(Icons.location_city, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          user['city'],
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (user['distance'] != null) ...[
                        Icon(Icons.near_me, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(user['distance']),
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // О себе
                  if (user['bio'] != null && user['bio'].isNotEmpty) ...[
                    const Text(
                      'О себе',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user['bio'],
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Общие интересы
                  if (commonInterests.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.pink, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Общие интересы',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.pink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${commonInterests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: commonInterests.map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            interest,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Все интересы
                  if (interests.isNotEmpty) ...[
                    const Text(
                      'Интересы',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: interests.map((interest) {
                        final isCommon = commonInterests.contains(interest);
                        return Chip(
                          label: Text(
                            interest,
                            style: TextStyle(color: isCommon ? Colors.white : null),
                          ),
                          backgroundColor: isCommon
                              ? Colors.pink
                              : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // Кнопки действий
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.close,
                color: Colors.grey,
                size: 60,
                onTap: () {
                  onDislike?.call();
                  Navigator.pop(context);
                },
              ),
              _ActionButton(
                icon: Icons.favorite,
                color: Colors.pink,
                size: 70,
                isMain: true,
                onTap: () {
                  onLike?.call();
                  Navigator.pop(context);
                },
              ),
              _ActionButton(
                icon: Icons.chat_bubble,
                color: Colors.blue,
                size: 60,
                onTap: () {
                  // TODO: Открыть чат если матч
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.person, size: 120, color: Colors.grey),
    );
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return '';
    final km = distance is int ? distance.toDouble() : distance as double;
    if (km < 1) return '${(km * 1000).round()} м';
    return '${km.toStringAsFixed(1)} км';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool isMain;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    this.isMain = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isMain ? color : (isDark ? Colors.grey[800] : Colors.white),
          shape: BoxShape.circle,
          border: isMain ? null : Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isMain ? Colors.white : color,
          size: size * 0.45,
        ),
      ),
    );
  }
}
