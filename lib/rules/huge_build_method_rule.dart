import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags any `build()` method whose body spans more than [_maxLines] source
/// lines. Massive build methods are hard to read and rebuild every frame —
/// extract subtrees into small widgets.
class HugeBuildMethodRule extends AuditRule {
  static const _maxLines = 80;

  @override
  String get id => 'huge_build_method';

  @override
  String get category => 'architecture';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description => 'build() method is too long — extract subwidgets';

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
    if (node.name.lexeme != 'build') {
      super.visitMethodDeclaration(node);
      return;
    }
    final body = node.body;
    if (body is! BlockFunctionBody) {
      super.visitMethodDeclaration(node);
      return;
    }
    final startLine = file.unit.lineInfo.getLocation(body.offset).lineNumber;
    final endLine = file.unit.lineInfo.getLocation(body.end).lineNumber;
    final span = endLine - startLine;
    if (span <= HugeBuildMethodRule._maxLines) {
      super.visitMethodDeclaration(node);
      return;
    }
    final loc = file.unit.lineInfo.getLocation(node.name.offset);
    issues.add(
      Issue(
        ruleId: 'huge_build_method',
        category: 'architecture',
        severity: Severity.warning,
        message:
            'build() spans $span lines (limit ${HugeBuildMethodRule._maxLines})',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion:
            'Extract subtrees into small widgets — each one is easier to read and can be const',
      ),
    );
    super.visitMethodDeclaration(node);
  }
}
