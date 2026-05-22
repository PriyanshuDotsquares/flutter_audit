import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `await` on a network call (http / Dio / Supabase / Firebase) that
/// is not enclosed in a try/catch. Network calls throw; unhandled exceptions
/// crash the app or break state.
class MissingTryCatchRule extends AuditRule {
  @override
  String get id => 'missing_try_catch';

  @override
  String get category => 'api';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  String get description => 'Network calls should be wrapped in try/catch';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  static const _networkTargets = {
    'http',
    'Dio',
    'dio',
    'client',
    'supabase',
    'Supabase',
    'firestore',
    'Firestore',
    'FirebaseFirestore',
  };
  static const _networkMethods = {
    'get',
    'post',
    'put',
    'delete',
    'patch',
    'send',
    'fetch',
    'request',
  };

  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitAwaitExpression(AwaitExpression node) {
    final expr = node.expression;
    if (expr is MethodInvocation && _isNetworkCall(expr)) {
      if (!_insideTry(node)) {
        final loc = file.unit.lineInfo.getLocation(node.offset);
        issues.add(
          Issue(
            ruleId: 'missing_try_catch',
            category: 'api',
            severity: Severity.warning,
            message: 'Network call not wrapped in try/catch',
            filePath: file.source.path,
            line: loc.lineNumber,
            column: loc.columnNumber,
            codeSnippet: file.lineAt(loc.lineNumber),
            suggestion:
                'Wrap in try/catch and surface the error to the user / logger',
          ),
        );
      }
    }
    super.visitAwaitExpression(node);
  }

  bool _isNetworkCall(MethodInvocation mi) {
    final target = mi.target;
    final targetName = target is SimpleIdentifier
        ? target.name
        : target is PrefixedIdentifier
        ? target.prefix.name
        : null;
    if (targetName == null) return false;
    if (!_networkTargets.contains(targetName)) return false;
    return _networkMethods.contains(mi.methodName.name);
  }

  bool _insideTry(AstNode node) {
    AstNode? n = node.parent;
    while (n != null) {
      if (n is TryStatement) return true;
      n = n.parent;
    }
    return false;
  }
}
