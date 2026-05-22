import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags business-logic calls (network, file I/O, persistence) inside a
/// Widget / State class. Widgets should delegate to services so logic is
/// testable and the UI layer stays thin.
class BusinessLogicInWidgetRule extends AuditRule {
  @override
  String get id => 'business_logic_in_widget';

  @override
  String get category => 'architecture';

  @override
  Severity get defaultSeverity => Severity.error;

  @override
  String get description =>
      'Business logic (http / DB / file I/O) inside a Widget or State class';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  static const _suspectTargets = {
    'http',
    'Dio',
    'File',
    'Directory',
    'SharedPreferences',
    'Hive',
    'FirebaseFirestore',
    'Firestore',
    'Supabase',
    'sqflite',
  };

  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_isWidgetOrState(node)) {
      super.visitClassDeclaration(node);
      return;
    }
    final inner = _SuspectVisitor(file, issues, node.name.lexeme);
    node.visitChildren(inner);
    super.visitClassDeclaration(node);
  }

  bool _isWidgetOrState(ClassDeclaration cls) {
    final s = cls.extendsClause?.superclass.name2.lexeme ?? '';
    return s == 'StatelessWidget' ||
        s == 'StatefulWidget' ||
        s == 'State' ||
        s.endsWith('Widget') ||
        s.endsWith('State');
  }
}

class _SuspectVisitor extends RecursiveAstVisitor<void> {
  final ParsedFile file;
  final List<Issue> issues;
  final String enclosingClass;
  final Set<int> reportedLines = {};

  _SuspectVisitor(this.file, this.issues, this.enclosingClass);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    String? targetName;
    if (target is SimpleIdentifier) {
      targetName = target.name;
    } else if (target is PrefixedIdentifier) {
      targetName = target.prefix.name;
    }
    if (targetName != null && _Visitor._suspectTargets.contains(targetName)) {
      _report(node.offset, '$targetName.${node.methodName.name}()');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name2.lexeme;
    if (_Visitor._suspectTargets.contains(name)) {
      _report(node.offset, 'new $name(…)');
    }
    super.visitInstanceCreationExpression(node);
  }

  void _report(int offset, String snippet) {
    final loc = file.unit.lineInfo.getLocation(offset);
    if (reportedLines.contains(loc.lineNumber)) return;
    reportedLines.add(loc.lineNumber);
    issues.add(
      Issue(
        ruleId: 'business_logic_in_widget',
        category: 'architecture',
        severity: Severity.error,
        message:
            'Business logic ($snippet) inside widget class `$enclosingClass`',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion:
            'Move to a service / repository and inject it; keep widgets UI-only',
      ),
    );
  }
}
