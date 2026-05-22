/// Score breakdown by category, each 0–100.
class AuditScore {
  final int architecture;
  final int performance;
  final int memory;
  final int ui;
  final int api;
  final int security;
  final int quality;

  const AuditScore({
    required this.architecture,
    required this.performance,
    required this.memory,
    required this.ui,
    required this.api,
    required this.security,
    required this.quality,
  });

  /// Weighted average across all categories.
  int get overall {
    // Security and memory weighted higher because they cause crashes/breaches.
    final weighted =
        (architecture * 1.0) +
        (performance * 1.2) +
        (memory * 1.5) +
        (ui * 0.8) +
        (api * 1.2) +
        (security * 1.5) +
        (quality * 0.8);
    final totalWeight = 1.0 + 1.2 + 1.5 + 0.8 + 1.2 + 1.5 + 0.8;
    return (weighted / totalWeight).round().clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
    'architecture': architecture,
    'performance': performance,
    'memory': memory,
    'ui': ui,
    'api': api,
    'security': security,
    'quality': quality,
    'overall': overall,
  };
}
