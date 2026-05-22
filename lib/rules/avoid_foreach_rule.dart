import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `iterable.forEach((x) => ...)` — prefer a `for-in` loop.
///
/// `forEach` with a closure is slower (closure allocation), can't `break`/
/// `continue`, and produces worse stack traces.
class AvoidForEachRule extends AuditRule {
  @override
  String get id => 'avoid_foreach';

  @override
  String get category => 'performance';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description => 'Prefer for-in over .forEach with a closure';

  @override
  List<Issue> check(ParsedFile file) {
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
    if (node.methodName.name == 'forEach' &&
        node.argumentList.arguments.length == 1 &&
        node.argumentList.arguments.first is FunctionExpression) {
      final loc = file.unit.lineInfo.getLocation(node.offset);
      issues.add(
        Issue(
          ruleId: 'avoid_foreach',
          category: 'performance',
          severity: Severity.warning,
          message:
              'Prefer `for (final x in iterable)` over `.forEach(closure)`',
          filePath: file.source.path,
          line: loc.lineNumber,
          column: loc.columnNumber,
          codeSnippet: file.lineAt(loc.lineNumber),
          suggestion: 'Replace with: `for (final item in iterable) { ... }`',
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}
