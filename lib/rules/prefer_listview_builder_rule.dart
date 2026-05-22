import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `ListView(children: [...])` or `Column(children: [...])` with many
/// items — large eager lists hurt scroll performance.
///
/// For ListView, suggest `ListView.builder`. For Column with > 10 children,
/// suggest splitting into smaller widgets.
class PreferListViewBuilderRule extends AuditRule {
  static const _eagerThreshold = 8;

  @override
  String get id => 'prefer_listview_builder';

  @override
  String get category => 'performance';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description =>
      'Use ListView.builder for large lists instead of eager children';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  static const _scrollables = {'ListView', 'GridView'};

  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && _scrollables.contains(node.methodName.name)) {
      _check(node.methodName.name, node.argumentList, node.offset);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name2.lexeme;
    if (_scrollables.contains(name) && node.constructorName.name == null) {
      _check(name, node.argumentList, node.offset);
    }
    super.visitInstanceCreationExpression(node);
  }

  void _check(String name, ArgumentList args, int offset) {
    for (final arg in args.arguments) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'children') continue;
      final value = arg.expression;
      if (value is! ListLiteral) continue;
      if (value.elements.length < PreferListViewBuilderRule._eagerThreshold) {
        continue;
      }
      final loc = file.unit.lineInfo.getLocation(offset);
      issues.add(
        Issue(
          ruleId: 'prefer_listview_builder',
          category: 'performance',
          severity: Severity.warning,
          message:
              '$name with ${value.elements.length} eager children — '
              'use $name.builder',
          filePath: file.source.path,
          line: loc.lineNumber,
          column: loc.columnNumber,
          codeSnippet: file.lineAt(loc.lineNumber),
          suggestion:
              'Switch to `$name.builder(itemCount: …, '
              'itemBuilder: (ctx, i) => …)`',
        ),
      );
    }
  }
}
