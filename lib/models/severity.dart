/// Severity levels for audit findings, ordered by impact.
///
/// Used for sorting issues, computing scores, and coloring terminal output.
enum Severity {
  /// Informational — style suggestions, not bugs.
  info,

  /// Warning — likely problem but app still works.
  warning,

  /// Error — definite bug that should be fixed.
  error,

  /// Critical — security risk or guaranteed crash.
  critical,
}

extension SeverityX on Severity {
  /// Human-readable label for terminal and reports.
  String get label => switch (this) {
    Severity.info => 'INFO',
    Severity.warning => 'WARNING',
    Severity.error => 'ERROR',
    Severity.critical => 'CRITICAL',
  };

  /// Points deducted from the category score per occurrence.
  int get scorePenalty => switch (this) {
    Severity.info => 1,
    Severity.warning => 2,
    Severity.error => 5,
    Severity.critical => 10,
  };
}
