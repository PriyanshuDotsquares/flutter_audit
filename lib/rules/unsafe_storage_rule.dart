import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags storing sensitive-sounding keys in SharedPreferences / Hive — these
/// stores aren't encrypted on disk. Use FlutterSecureStorage instead.
class UnsafeStorageRule extends AuditRule {
  @override
  String get id => 'unsafe_storage';

  @override
  String get category => 'security';

  @override
  Severity get defaultSeverity => Severity.error;

  @override
  String get description =>
      'Sensitive value stored in unencrypted store (SharedPreferences/Hive)';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

final _sensitiveKey = RegExp(
  r'(token|password|secret|api[_-]?key|jwt|refresh|session)',
  caseSensitive: false,
);

class _Visitor extends RecursiveAstVisitor<void> {
  static const _setters = {
    'setString',
    'setInt',
    'setBool',
    'setDouble',
    'put',
  };

  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.name;
    if (!_setters.contains(method)) {
      super.visitMethodInvocation(node);
      return;
    }
    final target = node.target;
    final targetName = target is SimpleIdentifier
        ? target.name
        : target is PrefixedIdentifier
        ? target.identifier.name
        : null;
    final looksUnsafe =
        targetName != null &&
        (targetName.contains('prefs') ||
            targetName.contains('Prefs') ||
            targetName.contains('Box') ||
            targetName.contains('box') ||
            targetName == 'SharedPreferences');
    if (!looksUnsafe) {
      super.visitMethodInvocation(node);
      return;
    }
    final args = node.argumentList.arguments;
    if (args.isEmpty) {
      super.visitMethodInvocation(node);
      return;
    }
    final first = args.first;
    if (first is! SimpleStringLiteral) {
      super.visitMethodInvocation(node);
      return;
    }
    if (!_sensitiveKey.hasMatch(first.value)) {
      super.visitMethodInvocation(node);
      return;
    }
    final loc = file.unit.lineInfo.getLocation(node.offset);
    issues.add(
      Issue(
        ruleId: 'unsafe_storage',
        category: 'security',
        severity: Severity.error,
        message: "Sensitive value '${first.value}' stored in unencrypted store",
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion:
            'Use flutter_secure_storage for tokens, passwords and similar data',
      ),
    );
    super.visitMethodInvocation(node);
  }
}
