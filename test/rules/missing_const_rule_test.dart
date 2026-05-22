import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_audit/core/parser.dart';
import 'package:flutter_audit/rules/missing_const_rule.dart';
import 'package:test/test.dart';

ParsedFile _parse(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  return ParsedFile(
    source: File('test.dart'),
    unit: result.unit,
    content: source,
  );
}

void main() {
  final rule = MissingConstRule();

  group('MissingConstRule — flags', () {
    test('Text widget without const', () {
      final file = _parse('Widget x() => Text("Hello");');
      final issues = rule.check(file);
      expect(issues, hasLength(1));
      expect(issues.first.ruleId, 'missing_const');
      expect(issues.first.message, contains('Text'));
    });

    test('SizedBox with numeric literal', () {
      final file = _parse('Widget x() => SizedBox(height: 16);');
      expect(rule.check(file), hasLength(1));
    });

    test('multiple nested widgets', () {
      final file = _parse('''
        Widget x() => Padding(
          padding: EdgeInsets.all(8),
          child: Text("Hi"),
        );
      ''');
      // Padding can be const (its arg EdgeInsets.all(8) is constant once marked).
      // EdgeInsets.all(8) can be const. Text("Hi") can be const.
      expect(rule.check(file), isNotEmpty);
    });
  });

  group('MissingConstRule — allows', () {
    test('already-const widget', () {
      final file = _parse('Widget x() => const Text("Hello");');
      expect(rule.check(file), isEmpty);
    });

    test('widget with non-constant argument', () {
      final file = _parse('''
        Widget x(String name) => Text(name);
      ''');
      expect(rule.check(file), isEmpty);
    });

    test('widget with string interpolation', () {
      final file = _parse(r'''
        Widget x(String name) => Text("Hello $name");
      ''');
      expect(rule.check(file), isEmpty);
    });

    test('widget inside const context', () {
      final file = _parse('''
        Widget x() => const Padding(
          padding: EdgeInsets.all(8),
          child: Text("Hi"),
        );
      ''');
      // Both inner widgets are inside `const Padding`, so no findings.
      expect(rule.check(file), isEmpty);
    });

    test('non-widget classes like Future or Exception', () {
      final file = _parse('''
        void x() {
          throw Exception("boom");
          Future.delayed(Duration(seconds: 1));
        }
      ''');
      // Exception and Future are in the skip list. Duration itself may be
      // flagged — that's actually a true positive (Duration can be const).
      final issues = rule.check(file);
      expect(issues.any((i) => i.message.contains('Exception')), isFalse);
      expect(issues.any((i) => i.message.contains('Future')), isFalse);
    });

    test('Controller classes', () {
      final file = _parse('''
        void x() {
          TextEditingController();
          AnimationController();
        }
      ''');
      expect(rule.check(file), isEmpty);
    });
  });

  group('MissingConstRule — metadata', () {
    test('exposes correct id and category', () {
      expect(rule.id, 'missing_const');
      expect(rule.category, 'performance');
    });
  });
}
