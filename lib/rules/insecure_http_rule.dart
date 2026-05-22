import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `http://…` URLs in string literals (non-localhost). HTTP is
/// vulnerable to MITM; production traffic should use HTTPS.
class InsecureHttpRule extends AuditRule {
  @override
  String get id => 'insecure_http';

  @override
  String get category => 'security';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description =>
      'Insecure http:// URL — use https:// for production traffic';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

final _httpPattern = RegExp(
  r'^http://(?!localhost|127\.0\.0\.1|10\.0\.2\.2)',
  caseSensitive: false,
);

class _Visitor extends RecursiveAstVisitor<void> {
  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (!_httpPattern.hasMatch(node.value)) return;
    final loc = file.unit.lineInfo.getLocation(node.offset);
    issues.add(
      Issue(
        ruleId: 'insecure_http',
        category: 'security',
        severity: Severity.warning,
        message: 'Insecure http:// URL: ${node.value}',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion: 'Use https:// instead',
      ),
    );
  }
}
