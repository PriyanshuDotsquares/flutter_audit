import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `State<…>` classes that hold a `*Controller` field but don't
/// `.dispose()` it.
///
/// Controllers (AnimationController, TextEditingController, ScrollController,
/// PageController, FocusNode etc.) hold platform resources or listeners that
/// will leak on screen pop unless explicitly disposed.
class DisposeControllersRule extends AuditRule {
  @override
  String get id => 'dispose_controllers';

  @override
  String get category => 'memory';

  @override
  Severity get defaultSeverity => Severity.error;

  @override
  String get description =>
      'State classes must dispose any *Controller / FocusNode fields';

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
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_isStateClass(node)) {
      super.visitClassDeclaration(node);
      return;
    }

    final fields = _collectLifecycleFields(node);
    if (fields.isEmpty) {
      super.visitClassDeclaration(node);
      return;
    }

    final disposeBody = _findDisposeBody(node);
    for (final field in fields) {
      final mentioned = disposeBody != null && disposeBody.contains(field.name);
      if (mentioned) continue;
      issues.add(
        Issue(
          ruleId: 'dispose_controllers',
          category: 'memory',
          severity: Severity.error,
          message: '${field.typeName} `${field.name}` is never disposed',
          filePath: file.source.path,
          line: field.line,
          column: field.column,
          codeSnippet: file.lineAt(field.line),
          suggestion:
              'Override `dispose()` and call '
              '`${field.name}.dispose()` before `super.dispose()`',
        ),
      );
    }
    super.visitClassDeclaration(node);
  }

  bool _isStateClass(ClassDeclaration node) {
    final supertype = node.extendsClause?.superclass.name2.lexeme;
    if (supertype == null) return false;
    return supertype == 'State' || supertype.endsWith('State');
  }

  List<_Field> _collectLifecycleFields(ClassDeclaration cls) {
    const lifecycleTypes = {
      'AnimationController',
      'TextEditingController',
      'ScrollController',
      'PageController',
      'TabController',
      'FocusNode',
    };
    final out = <_Field>[];
    for (final member in cls.members) {
      if (member is! FieldDeclaration) continue;
      final type = member.fields.type;
      final typeName = type is NamedType ? type.name2.lexeme : null;
      final looksLifecycle =
          typeName != null &&
          (lifecycleTypes.contains(typeName) ||
              typeName.endsWith('Controller') ||
              typeName.endsWith('FocusNode'));
      if (!looksLifecycle) continue;
      for (final v in member.fields.variables) {
        final loc = file.unit.lineInfo.getLocation(v.name.offset);
        out.add(
          _Field(
            name: v.name.lexeme,
            typeName: typeName,
            line: loc.lineNumber,
            column: loc.columnNumber,
          ),
        );
      }
    }
    return out;
  }

  String? _findDisposeBody(ClassDeclaration cls) {
    for (final member in cls.members) {
      if (member is! MethodDeclaration) continue;
      if (member.name.lexeme != 'dispose') continue;
      final body = member.body;
      if (body is BlockFunctionBody) {
        final start = body.block.offset;
        final end = body.block.end;
        return file.content.substring(start, end);
      }
      if (body is ExpressionFunctionBody) {
        return body.expression.toSource();
      }
    }
    return null;
  }
}

class _Field {
  final String name;
  final String typeName;
  final int line;
  final int column;
  _Field({
    required this.name,
    required this.typeName,
    required this.line,
    required this.column,
  });
}
