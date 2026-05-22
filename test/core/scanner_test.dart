import 'dart:io';

import 'package:flutter_audit/core/scanner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Scanner', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scanner_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('finds .dart files recursively', () async {
      await File(
        p.join(tempDir.path, 'main.dart'),
      ).writeAsString('void main(){}');
      await Directory(p.join(tempDir.path, 'lib')).create();
      await File(
        p.join(tempDir.path, 'lib', 'app.dart'),
      ).writeAsString('class A{}');

      final files = await Scanner().scan(tempDir.path);
      expect(files, hasLength(2));
    });

    test('ignores non-Dart files', () async {
      await File(p.join(tempDir.path, 'README.md')).writeAsString('# hi');
      await File(
        p.join(tempDir.path, 'main.dart'),
      ).writeAsString('void main(){}');

      final files = await Scanner().scan(tempDir.path);
      expect(files, hasLength(1));
    });

    test('excludes generated files by default', () async {
      await File(p.join(tempDir.path, 'real.dart')).writeAsString('class X{}');
      await File(
        p.join(tempDir.path, 'foo.g.dart'),
      ).writeAsString('// generated');
      await File(
        p.join(tempDir.path, 'bar.freezed.dart'),
      ).writeAsString('// freezed');

      final files = await Scanner().scan(tempDir.path);
      expect(files, hasLength(1));
      expect(files.first.path, endsWith('real.dart'));
    });

    test('excludes build and .dart_tool directories', () async {
      await Directory(p.join(tempDir.path, 'build')).create();
      await File(
        p.join(tempDir.path, 'build', 'gen.dart'),
      ).writeAsString('// gen');
      await Directory(p.join(tempDir.path, '.dart_tool')).create();
      await File(
        p.join(tempDir.path, '.dart_tool', 'foo.dart'),
      ).writeAsString('// foo');
      await File(p.join(tempDir.path, 'real.dart')).writeAsString('class X{}');

      final files = await Scanner().scan(tempDir.path);
      expect(files, hasLength(1));
    });

    test('throws on non-existent directory', () {
      expect(
        () => Scanner().scan('/nonexistent/path/12345'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
