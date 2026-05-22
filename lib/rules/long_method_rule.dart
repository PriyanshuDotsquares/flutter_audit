import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags methods longer than [_maxLines] source lines. Long methods are
/// hard to read and test — split them.
class LongMethodRule extends AuditRule {
  static const _maxLines = 60;

  @override
  String get id => 'long_method';

  @override
  String get category => 'quality';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  String get description =>
      'Method body exceeds line limit — consider splitting';

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
  void visitMethodDeclaration(MethodDeclaration node) {
    _check(node.name.lexeme, node.body, node.name.offset);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _check(node.name.lexeme, node.functionExpression.body, node.name.offset);
    super.visitFunctionDeclaration(node);
  }

  void _check(String name, FunctionBody body, int nameOffset) {
    if (body is! BlockFunctionBody) return;
    // build() is covered by huge_build_method.
    if (name == 'build') return;
    final start = file.unit.lineInfo.getLocation(body.offset).lineNumber;
    final end = file.unit.lineInfo.getLocation(body.end).lineNumber;
    final span = end - start;
    if (span <= LongMethodRule._maxLines) return;
    final loc = file.unit.lineInfo.getLocation(nameOffset);
    issues.add(
      Issue(
        ruleId: 'long_method',
        category: 'quality',
        severity: Severity.info,
        message:
            'Method `$name` spans $span lines (limit ${LongMethodRule._maxLines})',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion: 'Split into smaller, named helpers',
      ),
    );
  }
}
