import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `print(...)` calls outside test files. Use a real logger so output
/// can be turned off in release builds and shipped to crash analytics.
class PrintInProductionRule extends AuditRule {
  @override
  String get id => 'print_in_production';

  @override
  String get category => 'api';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description => 'Avoid print() in production — use a logger';

  @override
  List<Issue> check(ParsedFile file) {
    if (file.source.path.contains('/test/') ||
        file.source.path.endsWith('_test.dart')) {
      return const [];
    }
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'print') {
      final loc = file.unit.lineInfo.getLocation(node.offset);
      issues.add(
        Issue(
          ruleId: 'print_in_production',
          category: 'api',
          severity: Severity.warning,
          message: 'print() statement in production code',
          filePath: file.source.path,
          line: loc.lineNumber,
          column: loc.columnNumber,
          codeSnippet: file.lineAt(loc.lineNumber),
          suggestion: 'Use a logger (package:logging) or debugPrint()',
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}
