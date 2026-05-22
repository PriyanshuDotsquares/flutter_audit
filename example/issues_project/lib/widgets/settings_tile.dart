import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  SettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.settings),
      title: Text('Settings'),
      subtitle: Text('Tap to configure'),
      trailing: Icon(Icons.chevron_right),
    );
  }
}
