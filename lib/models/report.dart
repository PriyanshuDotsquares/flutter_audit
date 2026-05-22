import 'audit_score.dart';
import 'issue.dart';

/// The complete audit result.
///
/// Produced by the rules engine, consumed by reporters.
class Report {
  final String projectName;
  final int filesScanned;
  final int linesAnalyzed;
  final Duration elapsed;
  final List<Issue> issues;
  final AuditScore scores;
  final DateTime timestamp;

  Report({
    required this.projectName,
    required this.filesScanned,
    required this.linesAnalyzed,
    required this.elapsed,
    required this.issues,
    required this.scores,
    required this.timestamp,
  });

  /// Issues grouped by category in deterministic order.
  Map<String, List<Issue>> get byCategory {
    final result = <String, List<Issue>>{};
    for (final issue in issues) {
      result.putIfAbsent(issue.category, () => []).add(issue);
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'project': projectName,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'filesScanned': filesScanned,
    'linesAnalyzed': linesAnalyzed,
    'elapsedMs': elapsed.inMilliseconds,
    'scores': scores.toJson(),
    'summary': {
      'total': issues.length,
      'byCategory': byCategory.map((k, v) => MapEntry(k, v.length)),
    },
    'issues': issues.map((i) => i.toJson()).toList(),
  };
}
