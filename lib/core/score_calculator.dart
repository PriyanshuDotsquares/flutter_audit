import '../models/audit_score.dart';
import '../models/issue.dart';
import '../models/severity.dart';

/// Converts a list of issues into 0-100 scores per category.
///
/// Each category starts at 100 and loses [Severity.scorePenalty] points
/// per finding. Floors at 0.
class ScoreCalculator {
  static const _categories = [
    'architecture',
    'performance',
    'memory',
    'ui',
    'api',
    'security',
    'quality',
  ];

  AuditScore compute(List<Issue> issues) {
    final scores = <String, int>{for (final cat in _categories) cat: 100};

    for (final issue in issues) {
      final current = scores[issue.category];
      if (current == null) continue;
      scores[issue.category] = (current - issue.severity.scorePenalty).clamp(
        0,
        100,
      );
    }

    return AuditScore(
      architecture: scores['architecture']!,
      performance: scores['performance']!,
      memory: scores['memory']!,
      ui: scores['ui']!,
      api: scores['api']!,
      security: scores['security']!,
      quality: scores['quality']!,
    );
  }
}
