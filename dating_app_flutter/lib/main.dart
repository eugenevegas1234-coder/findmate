import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FindMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people, size: 120, color: Colors.pink),
              const SizedBox(height: 32),
              const Text(
                'FindMate',
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Найди единомышленников',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategorySelectionScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Начать', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('Уже есть аккаунт? Войти'),
              ),
            ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбери интересы'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Выбери минимум 3 интереса, чтобы найти единомышленников',
              style: TextStyle(color: Colors.grey[600]),
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.pink : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.pink[700]!, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          size: 32,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          category['name']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _selectedCategories.length >= 3
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(
                              categories: _selectedCategories.toList(),
                            ),
                          ),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: Text(
                  'Продолжить (${_selectedCategories.length}/3)',
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

  void openChat({required int userId, required String userName, String? userPhoto}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
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
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: 'Поиск'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Матчи'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return DiscoverScreen(onOpenChat: openChat);
      case 1:
        return MatchesScreen(onOpenChat: openChat);
      case 2:
        return const ProfileScreen();
      default:
        return const SizedBox();
    }
  }
}
