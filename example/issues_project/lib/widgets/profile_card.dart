import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(child: Icon(Icons.person)),
            SizedBox(width: 12),
            Text('Jane Doe'),
          ],
        ),
      ),
    );
  }
}
