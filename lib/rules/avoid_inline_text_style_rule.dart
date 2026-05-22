import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags inline `TextStyle(...)` literals that hardcode `color:`,
/// `fontSize:`, or `fontWeight:`. Typography should come from the app's
/// theme so it can be re-skinned in one place.
class AvoidInlineTextStyleRule extends AuditRule {
  @override
  String get id => 'avoid_inline_text_style';

  @override
  String get category => 'ui';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  String get description =>
      'Inline TextStyle with hardcoded color/size — use Theme.of(context).textTheme';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  static const _hardcodedProps = {
    'color',
    'fontSize',
    'fontWeight',
    'fontFamily',
  };

  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(
      node.constructorName.type.name2.lexeme,
      node.argumentList,
      node.offset,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) {
      _check(node.methodName.name, node.argumentList, node.offset);
    }
    super.visitMethodInvocation(node);
  }

  void _check(String name, ArgumentList args, int offset) {
    if (name != 'TextStyle') return;
    final hardcoded = args.arguments.where((a) {
      if (a is! NamedExpression) return false;
      if (!_hardcodedProps.contains(a.name.label.name)) return false;
      final expr = a.expression;
      // Skip Theme.of(...) or context.textTheme.… style references.
      if (expr is MethodInvocation || expr is PropertyAccess) return false;
      return true;
    }).toList();
    if (hardcoded.isEmpty) return;
    final loc = file.unit.lineInfo.getLocation(offset);
    issues.add(
      Issue(
        ruleId: 'avoid_inline_text_style',
        category: 'ui',
        severity: Severity.info,
        message:
            'Inline TextStyle hardcodes '
            '${hardcoded.map((e) => (e as NamedExpression).name.label.name).join(", ")}',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion:
            'Move to ThemeData.textTheme and use Theme.of(context).textTheme.*',
      ),
    );
  }
}
