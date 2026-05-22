import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FeedScreen extends StatefulWidget {
  FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // MEMORY: controllers never disposed.
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // MEMORY: subscription never cancelled.
  StreamSubscription<int>? ticker;

  // MEMORY: stream controller never closed.
  final StreamController<String> events = StreamController<String>.broadcast();

  List<String> items = [];

  @override
  void initState() {
    super.initState();
    // ARCHITECTURE: business logic (network) inside a State class.
    // API: hardcoded URL, missing try/catch.
    http.get(Uri.parse('https://api.realbad-flutter.com/feed'));
    _load();
  }

  Future<void> _load() async {
    // PERF: forEach with a closure where a for-in would do.
    [1, 2, 3].forEach((i) => items.add('item-$i'));
  }

  @override
  Widget build(BuildContext context) {
    // ARCH: huge build method, deeply nested, with inline business logic
    // and a non-builder ListView with many eager children.
    return Scaffold(
      appBar: AppBar(title: Text('Feed')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // UI: hardcoded width/height.
            Container(
              width: 350,
              height: 220,
              color: Colors.blue,
              child: Center(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(4),
                      child: Container(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Row(
                              children: [
                                Icon(Icons.search),
                                // UI: inline TextStyle with hardcoded color/size.
                                Text(
                                  'Search',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            // Stretch the build method past the 80-line limit.
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            SizedBox(height: 4),
            // PERF: ListView with many eager children — should be .builder.
            // UI: dynamic children with `for` element and no key:.
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  Text('Header'),
                  for (final item in items) ListTile(title: Text(item)),
                  ListTile(title: Text('Footer 1')),
                  ListTile(title: Text('Footer 2')),
                  ListTile(title: Text('Footer 3')),
                  ListTile(title: Text('Footer 4')),
                  ListTile(title: Text('Footer 5')),
                  ListTile(title: Text('Footer 6')),
                  ListTile(title: Text('Footer 7')),
                  ListTile(title: Text('Footer 8')),
                ],
              ),
            ),
            // TODO: paginate the list eventually.
            TextField(controller: searchController),
          ],
        ),
      ),
    );
  }
}
