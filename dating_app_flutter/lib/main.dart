import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/matches_screen.dart';

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
              const Icon(Icons.favorite, size: 120, color: Colors.pink),
              const SizedBox(height: 32),
              const Text('FindMate', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Найди свою любовь', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey[600])),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CategorySelectionScreen()));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
                  child: const Text('Начать', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
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

  final List<Map<String, String>> _categories = [
    {'icon': '🎮', 'name': 'Геймеры'},
    {'icon': '💻', 'name': 'Программирование'},
    {'icon': '🏃', 'name': 'Спорт'},
    {'icon': '🎸', 'name': 'Музыка'},
    {'icon': '📚', 'name': 'Обучение'},
    {'icon': '🚀', 'name': 'Стартапы'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбери интересы'), backgroundColor: Colors.pink, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: 12, mainAxisSpacing: 12),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(category['icon']!, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 8),
                        Text(category['name']!, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _selectedCategories.length >= 3 ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterScreen(categories: _selectedCategories.toList()))) : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), backgroundColor: Colors.pink, foregroundColor: Colors.white),
              child: Text('Продолжить (${_selectedCategories.length}/3)'),
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
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FindMate'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
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
        return const DiscoverScreen();
      case 1:
        return const MatchesScreen();
      case 2:
        return const ProfileScreen();
      default:
        return const SizedBox();
    }
  }
}
