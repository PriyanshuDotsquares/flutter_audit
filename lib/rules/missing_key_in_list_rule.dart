import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags widgets generated inside a `for`/`if` element of a children list
/// that don't pass a `key:`. Without keys, Flutter can't preserve state
/// when items reorder.
class MissingKeyInListRule extends AuditRule {
  @override
  String get id => 'missing_key_in_list';

  @override
  String get category => 'ui';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  String get description =>
      'Dynamic list items should pass a Key for stable identity';

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
  void visitListLiteral(ListLiteral node) {
    final hasDynamic = node.elements.any(_isDynamicElement);
    if (hasDynamic) {
      for (final element in node.elements) {
        _scanGeneratedWidgets(element);
      }
    }
    super.visitListLiteral(node);
  }

  bool _isDynamicElement(CollectionElement e) =>
      e is ForElement || e is IfElement;

  void _scanGeneratedWidgets(CollectionElement e) {
    if (e is ForElement) {
      _scanGeneratedWidgets(e.body);
    } else if (e is IfElement) {
      _scanGeneratedWidgets(e.thenElement);
      final elseE = e.elseElement;
      if (elseE != null) _scanGeneratedWidgets(elseE);
    } else if (e is Expression) {
      _checkExpression(e);
    }
  }

  void _checkExpression(Expression expr) {
    if (expr is InstanceCreationExpression) {
      _maybeReport(
        expr.constructorName.type.name2.lexeme,
        expr.argumentList,
        expr.offset,
      );
    } else if (expr is MethodInvocation && expr.target == null) {
      final name = expr.methodName.name;
      if (name.isNotEmpty && _isUpper(name[0])) {
        _maybeReport(name, expr.argumentList, expr.offset);
      }
    }
  }

  void _maybeReport(String widget, ArgumentList args, int offset) {
    final hasKey = args.arguments.any(
      (a) => a is NamedExpression && a.name.label.name == 'key',
    );
    if (hasKey) return;
    final loc = file.unit.lineInfo.getLocation(offset);
    issues.add(
      Issue(
        ruleId: 'missing_key_in_list',
        category: 'ui',
        severity: Severity.info,
        message:
            'Dynamic list item `$widget` has no key — state may shuffle on reorder',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion: 'Pass `key: ValueKey(item.id)` (or similar stable id)',
      ),
    );
  }

  bool _isUpper(String c) {
    final code = c.codeUnitAt(0);
    return code >= 65 && code <= 90;
  }
}
