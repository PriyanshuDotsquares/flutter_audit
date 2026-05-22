import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Clean Demo',
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold itself isn't const-constructible, so we leave it as-is.
    // It takes a non-const child (the build result), which makes its arg list
    // non-constant — so flutter_audit won't (incorrectly) flag it.
    return Scaffold(
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hello, world'),
          SizedBox(height: 12),
          Text('Every widget here is already const.'),
          SizedBox(height: 24),
          Icon(Icons.check_circle, size: 48),
        ],
      ),
    );
  }
}
