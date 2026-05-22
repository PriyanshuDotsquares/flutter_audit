import 'dart:io';
import 'package:path/path.dart' as p;

/// Walks a Flutter project directory and returns analyzable Dart files.
///
/// Skips generated files, build outputs, and the `.dart_tool` cache by default.
class Scanner {
  /// Directory names excluded if they appear anywhere in the path.
  final Set<String> excludeDirs;

  /// File-name suffixes (or exact names) that mark a file as generated.
  final List<String> excludeSuffixes;

  /// Exact basenames excluded regardless of location.
  final Set<String> excludeBasenames;

  Scanner({
    Set<String>? excludeDirs,
    List<String>? excludeSuffixes,
    Set<String>? excludeBasenames,
  }) : excludeDirs = excludeDirs ?? const {'.dart_tool', 'build', '.git'},
       excludeSuffixes =
           excludeSuffixes ??
           const ['.g.dart', '.freezed.dart', '.gr.dart', '.config.dart'],
       excludeBasenames =
           excludeBasenames ?? const {'generated_plugin_registrant.dart'};

  /// Scans [rootPath] recursively and returns every `.dart` file that
  /// isn't excluded by the configured rules.
  Future<List<File>> scan(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw FileSystemException('Directory not found', rootPath);
    }

    final files = <File>[];

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final relative = p.relative(entity.path, from: rootPath);
      if (_isExcluded(relative)) continue;

      files.add(entity);
    }

    return files;
  }

  bool _isExcluded(String relativePath) {
    final segments = p.split(relativePath);
    for (final segment in segments) {
      if (excludeDirs.contains(segment)) return true;
    }
    final basename = p.basename(relativePath);
    if (excludeBasenames.contains(basename)) return true;
    for (final suffix in excludeSuffixes) {
      if (basename.endsWith(suffix)) return true;
    }
    return false;
  }
}
