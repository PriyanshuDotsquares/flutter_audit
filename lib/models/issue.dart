import 'severity.dart';

/// A single audit finding.
///
/// One [Issue] represents one location in one file where a rule fired.
/// Every rule produces a list of these, and the reporter aggregates them.
class Issue {
  /// Unique rule identifier, e.g. `'missing_const'`.
  final String ruleId;

  /// Category for grouping, e.g. `'performance'`, `'memory'`, `'security'`.
  final String category;

  /// Severity level for this specific finding.
  final Severity severity;

  /// Human-readable description of what was detected.
  final String message;

  /// Absolute or project-relative file path.
  final String filePath;

  /// 1-based line number where the issue starts.
  final int line;

  /// 1-based column number where the issue starts.
  final int column;

  /// The offending line of source code, for display in reports.
  final String? codeSnippet;

  /// Suggested fix shown to the developer.
  final String? suggestion;

  const Issue({
    required this.ruleId,
    required this.category,
    required this.severity,
    required this.message,
    required this.filePath,
    required this.line,
    required this.column,
    this.codeSnippet,
    this.suggestion,
  });

  Map<String, dynamic> toJson() => {
    'ruleId': ruleId,
    'category': category,
    'severity': severity.name,
    'message': message,
    'file': filePath,
    'line': line,
    'column': column,
    if (codeSnippet != null) 'snippet': codeSnippet,
    if (suggestion != null) 'suggestion': suggestion,
  };

  @override
  String toString() => '$filePath:$line:$column [$ruleId] $message';
}
