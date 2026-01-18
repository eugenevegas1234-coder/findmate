import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await apiService.getProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          profile: _profile!,
          onSave: () => _loadProfile(),
        ),
      ),
    );
  }

  void _editInterests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditInterestsScreen(
          currentInterests: List<String>.from(_profile!['interests'] ?? []),
          onSave: (newInterests) async {
            await apiService.updateProfile({'interests': newInterests});
            _loadProfile();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null || _profile!.isEmpty) {
      return const Center(child: Text('Ошибка загрузки профиля'));
    }

    final interests = List<String>.from(_profile!['interests'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 60,
            backgroundColor: Colors.pink,
            child: Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            '${_profile!['name']}, ${_profile!['age'] ?? '?'}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            _profile!['email'] ?? '',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (_profile!['city'] != null || _profile!['gender'] != null)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_profile!['city'] != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.pink),
                        const SizedBox(width: 5),
                        Text(_profile!['city']),
                      ],
                    ),
                  if (_profile!['gender'] != null)
                    Row(
                      children: [
                        const Icon(Icons.person_outline, color: Colors.pink),
                        const SizedBox(width: 5),
                        Text(_profile!['gender']),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          if (_profile!['bio'] != null && _profile!['bio'].toString().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('О себе', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(_profile!['bio']),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Интересы', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.pink),
                      onPressed: _editInterests,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (interests.isEmpty)
                  Text('Нет интересов', style: TextStyle(color: Colors.grey[500]))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: interests.map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.pink, Colors.orange]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          interest,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Редактировать профиль'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onSave;

  const EditProfileScreen({super.key, required this.profile, required this.onSave});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  String? _gender;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['name']);
    _ageController = TextEditingController(text: widget.profile['age']?.toString() ?? '');
    _bioController = TextEditingController(text: widget.profile['bio'] ?? '');
    _cityController = TextEditingController(text: widget.profile['city'] ?? '');
    _gender = widget.profile['gender'];
  }

  Future<void> _save() async {
    try {
      await apiService.updateProfile({
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text),
        'bio': _bioController.text,
        'city': _cityController.text,
        'gender': _gender,
      });
      widget.onSave();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль сохранён!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка сохранения'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Возраст', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Город', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Пол', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Мужской', child: Text('Мужской')),
                DropdownMenuItem(value: 'Женский', child: Text('Женский')),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'О себе', border: OutlineInputBorder()),
              maxLines: 4,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditInterestsScreen extends StatefulWidget {
  final List<String> currentInterests;
  final Function(List<String>) onSave;

  const EditInterestsScreen({super.key, required this.currentInterests, required this.onSave});

  @override
  State<EditInterestsScreen> createState() => _EditInterestsScreenState();
}

class _EditInterestsScreenState extends State<EditInterestsScreen> {
  final List<String> _allInterests = [
    'Музыка', 'Кино', 'Спорт', 'Путешествия', 'Фотография',
    'Кулинария', 'Искусство', 'Танцы', 'Йога', 'Книги',
    'Игры', 'Технологии', 'Природа', 'Животные', 'Мода',
    'Программирование', 'Геймеры', 'Фитнес', 'Медитация', 'Бизнес',
  ];

  late List<String> _selectedInterests;

  @override
  void initState() {
    super.initState();
    _selectedInterests = List.from(widget.currentInterests);
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else if (_selectedInterests.length < 10) {
        _selectedInterests.add(interest);
      }
    });
  }

  void _save() {
    widget.onSave(_selectedInterests);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои интересы'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Выбрано: ${_selectedInterests.length}/10', style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _allInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return GestureDetector(
                    onTap: () => _toggleInterest(interest),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected ? const LinearGradient(colors: [Colors.pink, Colors.orange]) : null,
                        color: isSelected ? null : Colors.grey[200],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Text(
                        interest,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Сохранить интересы'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
