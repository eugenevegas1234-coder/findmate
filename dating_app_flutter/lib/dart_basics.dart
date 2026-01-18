void main() {
  print('=== Урок 6: Классы ===');
  
  // Создаём пользователя
  User user1 = User('Дмитрий', 25, 'Москва');
  user1.showInfo();
  
  // Создаём второго пользователя
  User user2 = User('Анна', 23, 'Питер');
  user2.showInfo();
  
  // Используем методы
  user1.addHobby('Музыка');
  user1.addHobby('Спорт');
  user1.showHobbies();
  
  // Проверяем совместимость
  print('Совместимость: ${user1.getMatch(user2)}%');
}

// Класс User - шаблон пользователя
class User {
  // Свойства (данные)
  String name;
  int age;
  String city;
  List<String> hobbies = [];
  
  // Конструктор - создание объекта
  User(this.name, this.age, this.city);
  
  // Метод - показать информацию
  void showInfo() {
    print('--- $name ---');
    print('Возраст: $age');
    print('Город: $city');
  }
  
  // Метод - добавить хобби
  void addHobby(String hobby) {
    hobbies.add(hobby);
  }
  
  // Метод - показать хобби
  void showHobbies() {
    print('Хобби $name: $hobbies');
  }
  
  // Метод - рассчитать совместимость
  int getMatch(User other) {
    int score = 50;
    if (city == other.city) score += 30;
    if ((age - other.age).abs() <= 5) score += 20;
    return score;
  }
}
