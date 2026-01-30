import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'utils/app_theme.dart';
import 'utils/page_transitions.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/chat_screen.dart';
import 'widgets/notification_banner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  String? _savedToken;

  @override
  void initState() {
    super.initState();
    themeService.addListener(_onThemeChanged);
    _checkSavedToken();
  }

  Future<void> _checkSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null && token.isNotEmpty) {
      apiService.setToken(token);
      setState(() {
        _savedToken = token;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeService.themeMode,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'FindMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      home: _savedToken != null 
          ? MainScreen(token: _savedToken!)
          : const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.diversity_3,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'FindMate',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Найди единомышленников',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          SlideUpRoute(page: const CategorySelectionScreen()),
                        );
                      },
                      child: const Text('Начать', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        FadeScaleRoute(page: const LoginScreen()),
                      );
                    },
                    child: const Text('Уже есть аккаунт? Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final Set<String> _selectedCategories = {};
  
  // Минимум 5 интересов
  static const int _minInterests = 5;

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.games, 'name': 'Геймеры'},
    {'icon': Icons.code, 'name': 'Программирование'},
    {'icon': Icons.computer, 'name': 'IT и технологии'},
    {'icon': Icons.rocket_launch, 'name': 'Стартапы'},
    {'icon': Icons.science, 'name': 'Наука'},
    {'icon': Icons.fitness_center, 'name': 'Спорт'},
    {'icon': Icons.directions_run, 'name': 'Бег'},
    {'icon': Icons.pool, 'name': 'Плавание'},
    {'icon': Icons.sports_basketball, 'name': 'Баскетбол'},
    {'icon': Icons.sports_soccer, 'name': 'Футбол'},
    {'icon': Icons.hiking, 'name': 'Походы'},
    {'icon': Icons.pedal_bike, 'name': 'Велоспорт'},
    {'icon': Icons.music_note, 'name': 'Музыка'},
    {'icon': Icons.brush, 'name': 'Рисование'},
    {'icon': Icons.camera_alt, 'name': 'Фотография'},
    {'icon': Icons.movie, 'name': 'Кино'},
    {'icon': Icons.theater_comedy, 'name': 'Театр'},
    {'icon': Icons.edit, 'name': 'Писательство'},
    {'icon': Icons.school, 'name': 'Обучение'},
    {'icon': Icons.menu_book, 'name': 'Книги'},
    {'icon': Icons.language, 'name': 'Языки'},
    {'icon': Icons.psychology, 'name': 'Психология'},
    {'icon': Icons.flight, 'name': 'Путешествия'},
    {'icon': Icons.restaurant, 'name': 'Кулинария'},
    {'icon': Icons.local_cafe, 'name': 'Кофе'},
    {'icon': Icons.nightlife, 'name': 'Вечеринки'},
    {'icon': Icons.pets, 'name': 'Животные'},
    {'icon': Icons.park, 'name': 'Природа'},
    {'icon': Icons.yard, 'name': 'Садоводство'},
    {'icon': Icons.business, 'name': 'Бизнес'},
    {'icon': Icons.trending_up, 'name': 'Инвестиции'},
    {'icon': Icons.work, 'name': 'Карьера'},
    {'icon': Icons.volunteer_activism, 'name': 'Волонтёрство'},
    {'icon': Icons.auto_stories, 'name': 'Аниме'},
    {'icon': Icons.sports_esports, 'name': 'Киберспорт'},
    {'icon': Icons.checkroom, 'name': 'Мода'},
    {'icon': Icons.self_improvement, 'name': 'Медитация'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбери интересы'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Выбери минимум $_minInterests интересов, чтобы найти единомышленников',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategories.contains(category['name']);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedCategories.remove(category['name']);
                      } else {
                        _selectedCategories.add(category['name']!);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.primaryGradient : null,
                      color: isSelected
                          ? null
                          : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          size: 32,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            category['name']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.grey[300] : Colors.black87),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
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
              child: ElevatedButton(
                onPressed: _selectedCategories.length >= _minInterests
                    ? () => Navigator.push(
                          context,
                          SlideRightRoute(
                            page: RegisterScreen(
                              categories: _selectedCategories.toList(),
                            ),
                          ),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(
                  'Продолжить (${_selectedCategories.length}/$_minInterests)',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String token;

  const MainScreen({super.key, required this.token});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  OverlayEntry? _notificationOverlay;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  void _setupNotifications() {
    notificationService.onNotification = (title, body, {int? userId, String? userName}) {
      _showNotificationBanner(title, body, userId: userId, userName: userName);
    };
  }

  void _showNotificationBanner(String title, String body, {int? userId, String? userName}) {
    _notificationOverlay?.remove();

    _notificationOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: NotificationBanner(
          title: title,
          body: body,
          onTap: () {
            if (userId != null && userName != null) {
              openChat(userId: userId, userName: userName);
            }
          },
          onDismiss: () {
            _notificationOverlay?.remove();
            _notificationOverlay = null;
          },
        ),
      ),
    );

    Overlay.of(context).insert(_notificationOverlay!);
  }

  @override
  void dispose() {
    _notificationOverlay?.remove();
    notificationService.onNotification = null;
    super.dispose();
  }

  void openChat({required int userId, required String userName, String? userPhoto}) {
    Navigator.push(
      context,
      SlideRightRoute(
        page: ChatScreen(
          userId: userId,
          userName: userName,
          userPhoto: userPhoto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(),
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: notificationService.unreadCount,
        builder: (context, unreadCount, child) {
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              if (index == 1) {
                notificationService.clearUnread();
              }
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Поиск',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.favorite_outline),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.favorite),
                ),
                label: 'Матчи',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return DiscoverScreen(key: const ValueKey('discover'), onOpenChat: openChat);
      case 1:
        return MatchesScreen(key: const ValueKey('matches'), onOpenChat: openChat);
      case 2:
        return const ProfileScreen(key: ValueKey('profile'));
      default:
        return const SizedBox();
    }
  }
}
