import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_audit/commands/scan_command.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'flutter_audit',
    'Static analysis CLI for Flutter projects.',
  )..addCommand(ScanCommand());

  try {
    final exitCode = await runner.run(args) ?? 0;
    exit(exitCode);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
