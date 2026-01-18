import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  bool _isUploading = false;
  final _picker = ImagePicker();

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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        print('No image selected');
        return;
      }

      setState(() => _isUploading = true);

      // Читаем файл как bytes (работает и на веб, и на мобильных)
      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name;

      final photoUrl = await apiService.uploadProfilePhotoBytes(bytes, filename);

      setState(() {
        _profile['photo'] = photoUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Фото успешно загружено!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error picking/uploading photo: $e');
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editProfile() {
    final nameController = TextEditingController(text: _profile['name'] ?? '');
    final ageController = TextEditingController(text: _profile['age']?.toString() ?? '');
    final cityController = TextEditingController(text: _profile['city'] ?? '');
    final bioController = TextEditingController(text: _profile['bio'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать профиль'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ageController,
                decoration: const InputDecoration(labelText: 'Возраст'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'Город'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: 'О себе'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'name': nameController.text,
                'age': int.tryParse(ageController.text),
                'city': cityController.text,
                'bio': bioController.text,
              };
              await apiService.updateProfile(data);
              Navigator.pop(context);
              _loadProfile();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _editInterests() {
    final allInterests = [
      'Музыка', 'Кино', 'Спорт', 'Путешествия', 'Книги',
      'Игры', 'Кулинария', 'Фотография', 'Танцы', 'Искусство',
      'Технологии', 'Природа', 'Йога', 'Мода', 'Наука'
    ];
    
    List<String> selected = List<String>.from(_profile['interests'] ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Мои интересы'),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allInterests.map((interest) {
                final isSelected = selected.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (value) {
                    setDialogState(() {
                      if (value) {
                        selected.add(interest);
                      } else {
                        selected.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                await apiService.updateProfile({'interests': selected});
                Navigator.pop(context);
                _loadProfile();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasPhoto = _profile['photo'] != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Аватар с возможностью загрузки фото
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadPhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.pink[100],
                  backgroundImage: hasPhoto
                      ? NetworkImage(apiService.getFullImageUrl(_profile['photo']))
                      : null,
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : !hasPhoto
                          ? const Icon(Icons.person, size: 60, color: Colors.pink)
                          : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.pink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          Text(
            'Нажмите чтобы изменить фото',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),

          const SizedBox(height: 16),

          // Имя и возраст
          Text(
            '${_profile['name'] ?? 'Имя не указано'}${_profile['age'] != null ? ', ${_profile['age']}' : ''}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          if (_profile['city'] != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                Text(_profile['city'], style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Кнопка редактирования
          ElevatedButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit),
            label: const Text('Редактировать профиль'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 24),

          // О себе
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('О себе', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    _profile['bio'] ?? 'Расскажите о себе...',
                    style: TextStyle(
                      color: _profile['bio'] != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Интересы
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Интересы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: _editInterests,
                        child: const Text('Изменить'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_profile['interests'] != null && (_profile['interests'] as List).isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_profile['interests'] as List).map((interest) {
                        return Chip(
                          label: Text(interest),
                          backgroundColor: Colors.pink[50],
                        );
                      }).toList(),
                    )
                  else
                    const Text(
                      'Добавьте интересы чтобы находить похожих людей',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
