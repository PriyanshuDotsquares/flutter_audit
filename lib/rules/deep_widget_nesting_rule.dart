import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags widget trees nested deeper than [_maxDepth] inside a single build
/// method. Deep trees are hard to read and refactor — extract subwidgets.
class DeepWidgetNestingRule extends AuditRule {
  static const _maxDepth = 10;

  @override
  String get id => 'deep_widget_nesting';

  @override
  String get category => 'architecture';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description =>
      'Widget tree nested too deeply — extract subwidgets';

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
  bool _reportedForCurrentBuild = false;

  _Visitor(this.file, this.issues);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'build') {
      super.visitMethodDeclaration(node);
      return;
    }
    _reportedForCurrentBuild = false;
    final deepest = _DepthMeter()..visit(node.body);
    if (deepest.maxDepth > DeepWidgetNestingRule._maxDepth &&
        !_reportedForCurrentBuild) {
      final loc = file.unit.lineInfo.getLocation(node.name.offset);
      issues.add(
        Issue(
          ruleId: 'deep_widget_nesting',
          category: 'architecture',
          severity: Severity.warning,
          message:
              'Widget tree nested ${deepest.maxDepth} levels (limit ${DeepWidgetNestingRule._maxDepth})',
          filePath: file.source.path,
          line: loc.lineNumber,
          column: loc.columnNumber,
          codeSnippet: file.lineAt(loc.lineNumber),
          suggestion: 'Extract inner widgets into named subwidgets',
        ),
      );
      _reportedForCurrentBuild = true;
    }
    super.visitMethodDeclaration(node);
  }
}

class _DepthMeter {
  int maxDepth = 0;

  void visit(AstNode node, [int depth = 0]) {
    var newDepth = depth;
    if (_isWidgetLikeNode(node)) {
      newDepth = depth + 1;
      if (newDepth > maxDepth) maxDepth = newDepth;
    }
    for (final child in node.childEntities) {
      if (child is AstNode) visit(child, newDepth);
    }
  }

  bool _isWidgetLikeNode(AstNode node) {
    if (node is InstanceCreationExpression) return true;
    if (node is MethodInvocation) {
      final target = node.target;
      final name = node.methodName.name;
      // Constructor-style call: capitalized.
      if (target == null && name.isNotEmpty && _isUpper(name[0])) return true;
      // Named constructor: ClassName.named(...)
      if (target is SimpleIdentifier &&
          target.name.isNotEmpty &&
          _isUpper(target.name[0])) {
        return true;
      }
    }
    return false;
  }

  bool _isUpper(String c) {
    final code = c.codeUnitAt(0);
    return code >= 65 && code <= 90;
  }
}
