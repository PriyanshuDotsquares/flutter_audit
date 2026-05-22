import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags large pixel-precise sizes (`width: 350`, `height: 200`) — these
/// don't adapt to screen size. Prefer MediaQuery or layout widgets.
class HardcodedSizeRule extends AuditRule {
  static const _threshold = 100;

  @override
  String get id => 'hardcoded_size';

  @override
  String get category => 'ui';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  String get description =>
      'Large hardcoded width/height — won\'t adapt to screen size';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  static const _sizeParams = {'width', 'height'};

  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    if (!_sizeParams.contains(name)) {
      super.visitNamedExpression(node);
      return;
    }
    final value = node.expression;
    num? literal;
    if (value is IntegerLiteral) literal = value.value;
    if (value is DoubleLiteral) literal = value.value;
    if (literal == null || literal < HardcodedSizeRule._threshold) {
      super.visitNamedExpression(node);
      return;
    }
    final loc = file.unit.lineInfo.getLocation(node.offset);
    issues.add(
      Issue(
        ruleId: 'hardcoded_size',
        category: 'ui',
        severity: Severity.info,
        message: 'Hardcoded $name: $literal — won\'t adapt to screen size',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion:
            'Use MediaQuery.of(context).size or a Flexible/Expanded layout',
      ),
    );
    super.visitNamedExpression(node);
  }
}
