import 'package:analyzer/dart/ast/token.dart';

import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';
import 'base_rule.dart';

/// Flags `TODO`/`FIXME`/`HACK`/`XXX` comments. These mark unfinished work
/// that should either get done or get tracked elsewhere.
class TodoCommentRule extends AuditRule {
  @override
  String get id => 'todo_comment';

  @override
  String get category => 'quality';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  String get description =>
      'TODO/FIXME comment found — track unfinished work elsewhere';

  @override
  List<Issue> check(ParsedFile file) {
    final issues = <Issue>[];
    Token? token = file.unit.beginToken;
    while (token != null) {
      var comment = token.precedingComments;
      while (comment != null) {
        final text = comment.lexeme;
        if (_todoPattern.hasMatch(text)) {
          final loc = file.unit.lineInfo.getLocation(comment.offset);
          issues.add(
            Issue(
              ruleId: 'todo_comment',
              category: 'quality',
              severity: Severity.info,
              message: text.trim(),
              filePath: file.source.path,
              line: loc.lineNumber,
              column: loc.columnNumber,
              codeSnippet: file.lineAt(loc.lineNumber),
              suggestion: 'Resolve the TODO or file an issue and reference it',
            ),
          );
        }
        comment = comment.next as dynamic;
      }
      if (token == token.next || token.next == null) break;
      token = token.next;
    }
    return issues;
  }
}

final _todoPattern = RegExp(r'\b(TODO|FIXME|XXX|HACK)\b');
