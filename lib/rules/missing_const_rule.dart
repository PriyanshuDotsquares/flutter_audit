import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Detects widget constructor invocations that could be marked `const` but
/// aren't.
///
/// Const widgets are cached and never rebuilt, so missing `const` is one of
/// the most common (and easiest to fix) performance issues in Flutter apps.
///
/// ### What this catches
/// ```dart
/// Text("Hello")                     // BAD — flagged
/// SizedBox(height: 16)              // BAD — flagged
/// EdgeInsets.all(8)                 // BAD — flagged
/// ```
///
/// ### What this allows
/// ```dart
/// const Text("Hello")               // already const
/// Text(name)                        // non-const arg — can't be const
/// Text("Hello $name")               // string interpolation — not constant
/// ```
class MissingConstRule extends AuditRule {
  @override
  String get id => 'missing_const';

  @override
  String get category => 'performance';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description =>
      'Widget constructor can be marked const for free performance';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    final visitor = _MissingConstVisitor(file, issues);
    file.unit.visitChildren(visitor);
    return issues;
  }
}

class _MissingConstVisitor extends RecursiveAstVisitor<void> {
  final ParsedFile file;
  final List<Issue> issues;

  _MissingConstVisitor(this.file, this.issues);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Already const — skip.
    if (node.isConst) {
      super.visitInstanceCreationExpression(node);
      return;
    }

    // Inside a const context (e.g. inside an already-const expression).
    // The analyzer handles propagation; if parent is const, this is too.
    if (_isInsideConstContext(node)) {
      super.visitInstanceCreationExpression(node);
      return;
    }

    // Must look like a widget. Heuristic: capitalized constructor name.
    final typeName = node.constructorName.type.name2.lexeme;
    if (!_looksLikeWidget(typeName)) {
      super.visitInstanceCreationExpression(node);
      return;
    }

    // All arguments must be compile-time constants for `const` to be legal.
    if (!_allArgsAreConstant(node.argumentList)) {
      super.visitInstanceCreationExpression(node);
      return;
    }

    _report(typeName, node.offset);
    super.visitInstanceCreationExpression(node);
  }

  // Without type resolution, `Text("Hello")` and `EdgeInsets.all(8)` parse as
  // MethodInvocation, not InstanceCreationExpression — the syntactic parser
  // can't distinguish a constructor call from a function call. We treat
  // capitalized invocations as likely constructor calls.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_looksLikeConstructorCall(node)) {
      super.visitMethodInvocation(node);
      return;
    }

    if (_isInsideConstContext(node)) {
      super.visitMethodInvocation(node);
      return;
    }

    final typeName = _displayName(node);
    if (!_looksLikeWidget(_classNameOf(node))) {
      super.visitMethodInvocation(node);
      return;
    }

    if (!_allArgsAreConstant(node.argumentList)) {
      super.visitMethodInvocation(node);
      return;
    }

    _report(typeName, node.offset);
    super.visitMethodInvocation(node);
  }

  bool _looksLikeConstructorCall(MethodInvocation node) {
    final target = node.target;
    if (target == null) {
      // Bare invocation like `Text(...)` — constructor iff name is capitalized.
      return _startsUpper(node.methodName.name);
    }
    // Named constructor like `EdgeInsets.all(...)` — class name must be
    // capitalized and the target must be a simple identifier.
    if (target is SimpleIdentifier) {
      return _startsUpper(target.name);
    }
    return false;
  }

  String _classNameOf(MethodInvocation node) {
    final target = node.target;
    if (target is SimpleIdentifier) return target.name;
    return node.methodName.name;
  }

  String _displayName(MethodInvocation node) {
    final target = node.target;
    if (target is SimpleIdentifier) {
      return '${target.name}.${node.methodName.name}';
    }
    return node.methodName.name;
  }

  bool _startsUpper(String name) {
    if (name.isEmpty) return false;
    return _isUpperCase(name[0]);
  }

  void _report(String typeName, int offset) {
    final location = file.unit.lineInfo.getLocation(offset);
    final snippet = file.lineAt(location.lineNumber);
    issues.add(
      Issue(
        ruleId: 'missing_const',
        category: 'performance',
        severity: Severity.warning,
        message: '`$typeName` can be marked const',
        filePath: file.source.path,
        line: location.lineNumber,
        column: location.columnNumber,
        codeSnippet: snippet,
        suggestion: 'Add the const keyword: `const $typeName(...)`',
      ),
    );
  }

  bool _isInsideConstContext(AstNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression && current.isConst) return true;
      if (current is ListLiteral && current.isConst) return true;
      if (current is SetOrMapLiteral && current.isConst) return true;
      // `const x = Foo()` / `static const Foo y = Foo()` / class const field.
      if (current is VariableDeclarationList && current.isConst) return true;
      current = current.parent;
    }
    return false;
  }

  bool _looksLikeWidget(String typeName) {
    if (typeName.isEmpty) return false;
    // Widgets and most const-friendly types start with uppercase.
    if (!_isUpperCase(typeName[0])) return false;
    // Skip clearly non-widget patterns.
    const skipList = {
      'Future',
      'Stream',
      'Completer',
      'StreamController',
      'StreamSubscription',
      'Timer',
      'Random',
      'RegExp',
      'DateTime',
      'Duration',
      'Uri',
      'Exception',
      'Error',
      'StateError',
      'ArgumentError',
    };
    if (skipList.contains(typeName)) return false;
    if (typeName.endsWith('Exception')) return false;
    if (typeName.endsWith('Error')) return false;
    if (typeName.endsWith('Controller')) return false;
    return true;
  }

  bool _isUpperCase(String char) {
    final code = char.codeUnitAt(0);
    return code >= 65 && code <= 90;
  }

  bool _allArgsAreConstant(ArgumentList args) {
    for (final arg in args.arguments) {
      final expr = arg is NamedExpression ? arg.expression : arg;
      if (!_isConstantExpression(expr)) return false;
    }
    return true;
  }

  bool _isConstantExpression(Expression expr) {
    // Literals that are always constant.
    if (expr is NullLiteral) return true;
    if (expr is BooleanLiteral) return true;
    if (expr is IntegerLiteral) return true;
    if (expr is DoubleLiteral) return true;
    if (expr is SymbolLiteral) return true;

    // String literals — only if no interpolation.
    if (expr is SimpleStringLiteral) return true;
    if (expr is StringInterpolation) return false;
    if (expr is AdjacentStrings) {
      return expr.strings.every(_isConstantExpression);
    }

    // List/Set/Map literals — constant iff already const-marked AND all
    // elements are constant.
    if (expr is ListLiteral) {
      if (!expr.isConst) return false;
      return expr.elements.whereType<Expression>().every(_isConstantExpression);
    }
    if (expr is SetOrMapLiteral) {
      return expr.isConst;
    }

    // Constructor calls — only if already const and all sub-args are const.
    if (expr is InstanceCreationExpression) {
      if (!expr.isConst) return false;
      return _allArgsAreConstant(expr.argumentList);
    }

    // Identifiers — could be a const variable. Conservative: only accept
    // PrefixedIdentifier like `Colors.red` (static const fields) and
    // SimpleIdentifier in ALL_CAPS or starting with `k` (Flutter convention
    // for constants).
    if (expr is PrefixedIdentifier) return true; // e.g. Colors.red, Icons.add
    if (expr is SimpleIdentifier) {
      final name = expr.name;
      if (name.startsWith('k') && name.length > 1 && _isUpperCase(name[1])) {
        return true;
      }
      if (name == name.toUpperCase() && name.length > 1) return true;
      return false;
    }

    // Property access like `Theme.of(context).colorScheme.primary` — not const.
    if (expr is MethodInvocation) return false;
    if (expr is PropertyAccess) {
      // Allow simple cases like `EdgeInsets.zero`.
      final target = expr.target;
      if (target is SimpleIdentifier && expr.propertyName.name == 'zero') {
        return true;
      }
      return false;
    }

    // Unary minus on a literal: `-1`
    if (expr is PrefixExpression && expr.operator.lexeme == '-') {
      return _isConstantExpression(expr.operand);
    }

    return false;
  }
}
