import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags fully-qualified URLs sprinkled through widget / state code. URLs
/// belong in a config layer so they can be swapped per environment.
class HardcodedUrlRule extends AuditRule {
  @override
  String get id => 'hardcoded_url';

  @override
  String get category => 'api';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  String get description =>
      'URL literal in widget/state code — move to a config';

  @override
  List<Issue> check(ParsedFile file) {
    // Skip config-like files where URLs legitimately live.
    final p = file.source.path;
    if (p.contains('config') || p.contains('constants') || p.contains('env')) {
      return const [];
    }
    final issues = <Issue>[];
    file.unit.visitChildren(_Visitor(file, issues));
    return issues;
  }
}

final _urlPattern = RegExp(r'^https?://[^\s]+$', caseSensitive: false);

class _Visitor extends RecursiveAstVisitor<void> {
  final ParsedFile file;
  final List<Issue> issues;

  _Visitor(this.file, this.issues);

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (!_urlPattern.hasMatch(node.value)) return;
    // Skip localhost & loopback — likely dev-only.
    if (node.value.contains('localhost') ||
        node.value.contains('127.0.0.1') ||
        node.value.contains('example.com')) {
      return;
    }
    final loc = file.unit.lineInfo.getLocation(node.offset);
    issues.add(
      Issue(
        ruleId: 'hardcoded_url',
        category: 'api',
        severity: Severity.info,
        message: 'Hardcoded URL in source: ${node.value}',
        filePath: file.source.path,
        line: loc.lineNumber,
        column: loc.columnNumber,
        codeSnippet: file.lineAt(loc.lineNumber),
        suggestion:
            'Move URLs to a config file (e.g. lib/config/api_endpoints.dart)',
      ),
    );
  }
}
