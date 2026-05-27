import 'dart:convert';
import 'dart:io';

class UserPreferences {
  final String? model;
  final double temperature;

  const UserPreferences({this.model, this.temperature = 0.5});
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
      );
    } on Exception {
      return const UserPreferences();
    }
  }

  Future<void> save(UserPreferences prefs) async {
    final map = <String, dynamic>{
      'temperature': prefs.temperature,
    };
    if (prefs.model != null) map['model'] = prefs.model;
    file.writeAsStringSync(jsonEncode(map));
  }
}
