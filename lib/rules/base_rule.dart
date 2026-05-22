import '../core/parser.dart';
import '../models/issue.dart';
import '../models/severity.dart';

/// The contract every audit rule must implement.
///
/// Adding a new rule means creating one file in `lib/rules/` that extends
/// this class and registering it in `lib/core/rules_engine.dart`. No other
/// code in the system needs to change.
abstract class AuditRule {
  /// Stable, snake_case identifier shown in reports and config files.
  /// Example: `'missing_const'`.
  String get id;

  /// Category bucket for grouping in the report.
  /// One of: architecture, performance, memory, ui, api, security, quality.
  String get category;

  /// Default severity if not overridden by `.flutter_audit.yaml`.
  Severity get defaultSeverity;

  /// One-line description shown in `flutter_audit rules` output.
  String get description;

  /// Inspect a parsed file and return any findings.
  ///
  /// MUST be pure (no side effects, no I/O). MUST be fast (<10ms typical).
  /// MUST return an empty list rather than throw on unexpected input.
  List<Issue> check(ParsedFile file);
}
