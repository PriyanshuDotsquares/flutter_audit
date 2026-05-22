import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags string literals that look like hardcoded API keys, tokens or
/// passwords assigned to a suspiciously-named identifier.
///
/// Heuristic: variable/field name matches /api_key|secret|token|password|
/// auth/i AND value is a literal string of ≥16 chars with no spaces.
class HardcodedSecretRule extends AuditRule {
  @override
  String get id => 'hardcoded_secret';

  @override
  String get category => 'security';

  @override
  Severity get defaultSeverity => Severity.critical;

  @override
  String get description =>
      'Possible hardcoded API key / token / password in source';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

final _suspiciousName = RegExp(
  r'(api[_-]?key|secret|token|password|passwd|auth[_-]?key)',
  caseSensitive: false,
);

bool _looksLikeKeyValue(String s) {
  if (s.length < 16) return false;
  if (s.contains(' ')) return false;
  if (s.contains('://')) return false; // URLs are not secrets
  // Mostly alphanumeric / base64-ish.
  final hits = RegExp(r'[A-Za-z0-9_\-+/=.]').allMatches(s).length;
  return hits / s.length > 0.8;
}

class _Visitor extends RecursiveAstVisitor<void> {
  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final name = node.name.lexeme;
    final init = node.initializer;
    if (init is SimpleStringLiteral && _suspiciousName.hasMatch(name)) {
      _report(name, init.value, init.offset);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final lhs = node.leftHandSide;
    final rhs = node.rightHandSide;
    final name = lhs is SimpleIdentifier
        ? lhs.name
        : lhs is PropertyAccess
        ? lhs.propertyName.name
        : null;
    if (name == null) {
      super.visitAssignmentExpression(node);
      return;
    }
    if (rhs is SimpleStringLiteral && _suspiciousName.hasMatch(name)) {
      _report(name, rhs.value, rhs.offset);
    }
    super.visitAssignmentExpression(node);
  }

  void _report(String name, String value, int offset) {
    if (!_looksLikeKeyValue(value)) return;
    final loc = file.unit.lineInfo.getLocation(offset);
    issues.add(
      Issue(
        ruleId: 'hardcoded_secret',
        category: 'security',
        severity: Severity.critical,
        message: 'Possible hardcoded secret in `$name`',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion:
            'Move to env (--dart-define) or a secure key store; never commit secrets',
      ),
    );
  }
}
