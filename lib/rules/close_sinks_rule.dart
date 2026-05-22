import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `StreamController` (or similar sink) fields in a State class whose
/// `dispose()` doesn't call `.close()` on them.
class CloseSinksRule extends AuditRule {
  @override
  String get id => 'close_sinks';

  @override
  String get category => 'memory';

  @override
  Severity get defaultSeverity => Severity.error;

  @override
  String get description =>
      'StreamController / Sink fields must be closed in dispose()';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  static const _sinkTypes = {
    'StreamController',
    'BehaviorSubject',
    'PublishSubject',
    'ReplaySubject',
    'Sink',
  };

  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final supertype = node.extendsClause?.superclass.name2.lexeme ?? '';
    final isStateClass = supertype == 'State' || supertype.endsWith('State');
    // Sinks/controllers can also live in plain services — flag those too,
    // but limit lint noise by requiring the class to declare a dispose method.
    final disposeBody = _disposeBody(node);

    for (final member in node.members) {
      if (member is! FieldDeclaration) continue;
      final type = member.fields.type;
      if (type is! NamedType) continue;
      final name = type.name2.lexeme;
      if (!_sinkTypes.contains(name) && !name.endsWith('Sink')) continue;

      for (final v in member.fields.variables) {
        final closed =
            disposeBody != null &&
            disposeBody.contains('${v.name.lexeme}.close');
        if (closed) continue;
        // Outside a State class we only flag if a dispose method is present
        // but doesn't close — otherwise we'd spam every utility class.
        if (!isStateClass && disposeBody == null) continue;
        final loc = file.unit.lineInfo.getLocation(v.name.offset);
        issues.add(
          Issue(
            ruleId: 'close_sinks',
            category: 'memory',
            severity: Severity.error,
            message: '$name `${v.name.lexeme}` is never closed',
            filePath: file.source.path,
            line: loc.lineNumber,
            column: loc.columnNumber,
            codeSnippet: file.lineAt(loc.lineNumber),
            suggestion: 'In dispose(), call `${v.name.lexeme}.close();`',
          ),
        );
      }
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
