import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags empty `catch` blocks. Swallowing errors makes bugs invisible.
class EmptyCatchRule extends AuditRule {
  @override
  String get id => 'empty_catch';

  @override
  String get category => 'quality';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description => 'Empty catch block swallows errors silently';

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
  void visitCatchClause(CatchClause node) {
    if (node.body.statements.isEmpty) {
      final loc = file.unit.lineInfo.getLocation(node.offset);
      issues.add(
        Issue(
          ruleId: 'empty_catch',
          category: 'quality',
          severity: Severity.warning,
          message: 'Empty catch block — error is silently discarded',
          filePath: file.source.path,
          line: loc.lineNumber,
          column: loc.columnNumber,
          codeSnippet: file.lineAt(loc.lineNumber),
          suggestion: 'At minimum, log the error or rethrow',
        ),
      );
    }
    super.visitCatchClause(node);
  }
}
