import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://168.110.194.144';

  static String? get googleServerClientId =>
      _blankToNull(dotenv.maybeGet('GOOGLE_SERVER_CLIENT_ID'));

  static String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }
}
