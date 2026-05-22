import '../models/issue.dart';
import '../rules/base_rule.dart';
import 'parser.dart';

/// Coordinates execution of all registered rules.
///
/// Takes the list of parsed files from [Parser], runs every rule against
/// every file, and returns the flat list of all findings.
class RulesEngine {
  final List<AuditRule> rules;

  RulesEngine(this.rules);

  /// Run every rule against every file. Returns all issues found.
  ///
  /// Rules that throw are skipped — a buggy rule should never crash the
  /// whole audit.
  List<Issue> run(List<ParsedFile> files) {
    final allIssues = <Issue>[];
    for (final file in files) {
      for (final rule in rules) {
        try {
          allIssues.addAll(rule.check(file));
        } catch (_) {
          // Skip rules that crash on weird input.
          continue;
        }
      }
    }
    return allIssues;
  }
}
