import 'dart:convert';
import 'dart:io';

class UserPreferences {
  final String? model;
  final double temperature;
  final bool darkMode;
  final double scrollOffset;

  const UserPreferences({
    this.model,
    this.temperature = 0.5,
    this.darkMode = false,
    this.scrollOffset = 0.0,
  });
}

class UserPreferencesService {
  final File file;

  UserPreferencesService({required this.file});

  Future<UserPreferences> load() async {
    if (!file.existsSync()) return const UserPreferences();
    try {
      final contents = await file.readAsString();
      final map = jsonDecode(contents) as Map<String, dynamic>;
      return UserPreferences(
        model: map['model'] as String?,
        temperature: (map['temperature'] as num?)?.toDouble() ?? 0.5,
        darkMode: (map['darkMode'] as bool?) ?? false,
        scrollOffset: (map['scrollOffset'] as num?)?.toDouble() ?? 0.0,
      );
    } on Exception {
      return const UserPreferences();
    }
  }

  Future<void> save(UserPreferences prefs) async {
    final map = <String, dynamic>{
      'temperature': prefs.temperature,
      'darkMode': prefs.darkMode,
      'scrollOffset': prefs.scrollOffset,
    };
    if (prefs.model != null) map['model'] = prefs.model;
    file.writeAsStringSync(jsonEncode(map));
  }
}
