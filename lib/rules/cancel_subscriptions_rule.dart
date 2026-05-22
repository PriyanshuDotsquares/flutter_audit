import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `StreamSubscription` (or `*Subscription`) fields in a State class
/// whose `dispose()` doesn't call `.cancel()` on them.
class CancelSubscriptionsRule extends AuditRule {
  @override
  String get id => 'cancel_subscriptions';

  @override
  String get category => 'memory';

  @override
  Severity get defaultSeverity => Severity.error;

  @override
  String get description =>
      'StreamSubscription fields must be cancelled in dispose()';

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
    final supertype = node.extendsClause?.superclass.name2.lexeme ?? '';
    if (!(supertype == 'State' || supertype.endsWith('State'))) {
      super.visitClassDeclaration(node);
      return;
    }

    final subs = <_Sub>[];
    for (final member in node.members) {
      if (member is! FieldDeclaration) continue;
      final type = member.fields.type;
      if (type is! NamedType) continue;
      final typeName = type.name2.lexeme;
      if (typeName != 'StreamSubscription' &&
          !typeName.endsWith('Subscription')) {
        continue;
      }
      for (final v in member.fields.variables) {
        final loc = file.unit.lineInfo.getLocation(v.name.offset);
        subs.add(
          _Sub(v.name.lexeme, typeName, loc.lineNumber, loc.columnNumber),
        );
      }
    }
    if (subs.isEmpty) {
      super.visitClassDeclaration(node);
      return;
    }

    final disposeBody = _disposeBody(node);
    for (final s in subs) {
      final cancelled =
          disposeBody != null && disposeBody.contains('${s.name}.cancel');
      if (cancelled) continue;
      issues.add(
        Issue(
          ruleId: 'cancel_subscriptions',
          category: 'memory',
          severity: Severity.error,
          message: '${s.type} `${s.name}` is never cancelled',
          filePath: file.source.path,
          line: s.line,
          column: s.column,
          codeSnippet: file.lineAt(s.line),
          suggestion: 'In dispose(), call `${s.name}.cancel();`',
        ),
      );
    }
    super.visitClassDeclaration(node);
  }

  String? _disposeBody(ClassDeclaration cls) {
    for (final m in cls.members) {
      if (m is! MethodDeclaration) continue;
      if (m.name.lexeme != 'dispose') continue;
      final body = m.body;
      if (body is BlockFunctionBody) {
        return file.content.substring(body.block.offset, body.block.end);
      }
    }
    return null;
  }
}

class _Sub {
  final String name;
  final String type;
  final int line;
  final int column;
  _Sub(this.name, this.type, this.line, this.column);
}
