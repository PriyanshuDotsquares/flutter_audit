import 'dart:async';
import 'package:http/http.dart' as http;

class ApiService {
  // SECURITY: insecure http:// URL.
  static const String baseUrl = 'http://api.example-bad.com/v1';

  Future<String> fetchUser(String id) async {
    // API: hardcoded URL in service file (allowed here, but it appears in
    // widgets too — see feed_screen.dart for the violation).
    // API: missing try/catch around the network call.
    final response = await http.get(Uri.parse('$baseUrl/users/$id'));

    // API: print() in production code.
    print('Fetched user $id -> status ${response.statusCode}');

    return response.body;
  }

  Future<void> fireAndForget() async {
    try {
      await http.post(Uri.parse('$baseUrl/events'));
    } catch (_) {
      // QUALITY: empty catch swallowing the network error.
    }
  }
}
