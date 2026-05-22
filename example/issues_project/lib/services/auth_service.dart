import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // SECURITY: hardcoded API key directly in source.
  static const String apiKey = 'sk_live_AKIA1234567890ABCDEFG';

  // SECURITY: hardcoded secret token.
  String authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abc.def_long_value';

  Future<void> persist(SharedPreferences prefs, String token) async {
    // SECURITY: storing token in (unencrypted) SharedPreferences.
    await prefs.setString('auth_token', token);
    // SECURITY: same problem, different key name.
    await prefs.setString('user_password', 'plaintext-pw');
  }
}
