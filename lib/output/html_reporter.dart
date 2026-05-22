import 'package:path/path.dart' as p;

import '../models/issue.dart';
import '../models/report.dart';
import '../models/severity.dart';

/// Renders a [Report] as a styled, self-contained HTML page.
///
/// The output is a single file with inline CSS — no external assets or
/// fonts to load. Drop it into a Slack message, attach to a ticket, or
/// open it locally with a browser.
class HtmlReporter {
  final String projectRoot;

  HtmlReporter({required this.projectRoot});

  String render(Report report) {
    final buf = StringBuffer();
    buf.write('<!doctype html>\n');
    buf.write('<html lang="en">\n');
    buf.write(_head(report.projectName));
    buf.write('<body>\n<div class="wrap">\n');
    buf.write(_cover(report));
    buf.write(_executiveSummary(report));
    buf.write(_scoresCard(report));
    buf.write(_findingsByCategory(report));
    buf.write(_topIssues(report));
    buf.write(_appendix(report));
    buf.write(_footer(report));
    buf.write('</div>\n</body>\n</html>\n');
    return buf.toString();
  }

  // --- sections ---------------------------------------------------------

  String _head(String project) =>
      '''
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_esc(project)} — Flutter Audit Report</title>
<style>
$_css
</style>
</head>
''';

  String _cover(Report r) {
    final date = r.timestamp.toLocal().toIso8601String().substring(0, 10);
    return '''
<header class="cover">
  <div class="eyebrow">Flutter Audit Report</div>
  <h1>${_esc(r.projectName)}</h1>
  <div class="sub">Static audit covering performance, memory, security, API hygiene, architecture, UI and code quality.</div>
  <div class="meta-grid">
    <div class="meta"><div class="k">Project</div><div class="v">${_esc(r.projectName)}</div></div>
    <div class="meta"><div class="k">Source size</div><div class="v">${r.linesAnalyzed} LOC · ${r.filesScanned} files</div></div>
    <div class="meta"><div class="k">Scan time</div><div class="v">${r.elapsed.inMilliseconds} ms</div></div>
    <div class="meta"><div class="k">Date</div><div class="v">$date</div></div>
  </div>
</header>
''';
  }

  String _executiveSummary(Report r) {
    final counts = _countBySeverity(r.issues);
    final overallGrade = _grade(r.scores.overall);
    return '''
<div class="card">
  <h2><span class="num">1</span> Executive summary</h2>
  <p class="lead">
    ${_summaryParagraph(r)}
  </p>

  <h3>Overall grade</h3>
  <div class="overall">
    <div class="overall-num ${_gradeClass(r.scores.overall)}">${r.scores.overall}</div>
    <div class="overall-meta">
      <div class="overall-grade">$overallGrade</div>
      <div class="overall-label">${_qualitative(r.scores.overall)}</div>
    </div>
  </div>

  <h3>Finding counts</h3>
  <div class="kpi-row">
    <div class="kpi"><div class="n crit">${counts['critical']}</div><div class="lbl">Critical</div></div>
    <div class="kpi"><div class="n high">${counts['error']}</div><div class="lbl">High</div></div>
    <div class="kpi"><div class="n med">${counts['warning']}</div><div class="lbl">Medium</div></div>
    <div class="kpi"><div class="n low">${counts['info']}</div><div class="lbl">Low / Info</div></div>
  </div>
</div>
''';
  }

  String _scoresCard(Report r) {
    final s = r.scores;
    String tile(String label, int score) {
      return '''
    <div class="score ${_gradeClass(score)}">
      <div class="grade">${_grade(score)}</div>
      <div class="num-small">$score / 100</div>
      <div class="label">$label</div>
    </div>''';
    }

    return '''
<div class="card">
  <h2><span class="num">2</span> Verdict by area</h2>
  <p class="lead">Each category starts at 100 and loses 1 / 2 / 5 / 10 points per info / warning / error / critical finding.</p>
  <div class="scores">
    ${tile('Architecture', s.architecture)}
    ${tile('Performance', s.performance)}
    ${tile('Memory', s.memory)}
    ${tile('UI Quality', s.ui)}
    ${tile('API Hygiene', s.api)}
    ${tile('Security', s.security)}
    ${tile('Code Quality', s.quality)}
  </div>
</div>
''';
  }

  String _findingsByCategory(Report r) {
    if (r.issues.isEmpty) {
      return '''
<div class="card">
  <h2><span class="num">3</span> Findings by category</h2>
  <p class="lead good-banner">No issues found. Every rule passed cleanly. <span class="pill good">PASS</span></p>
</div>
''';
    }

    final ordered = const [
      ['security', 'Security'],
      ['memory', 'Memory'],
      ['architecture', 'Architecture'],
      ['api', 'API'],
      ['performance', 'Performance'],
      ['ui', 'UI'],
      ['quality', 'Quality'],
    ];

    final buf = StringBuffer();
    buf.write('<div class="card">\n');
    buf.write('  <h2><span class="num">3</span> Findings by category</h2>\n');
    buf.write(
      '  <p class="lead">Every rule below produced at least one finding. Click a row to see the offending source line.</p>\n',
    );

    final grouped = r.byCategory;
    for (final pair in ordered) {
      final cat = pair[0];
      final label = pair[1];
      final issues = grouped[cat];
      if (issues == null || issues.isEmpty) continue;

      // group within category by ruleId
      final byRule = <String, List<Issue>>{};
      for (final i in issues) {
        byRule.putIfAbsent(i.ruleId, () => []).add(i);
      }

      buf.write(
        '  <h3 class="cat-h3">$label <span class="cat-count">${issues.length} issue${issues.length == 1 ? '' : 's'}</span></h3>\n',
      );
      buf.write('  <table>\n');
      buf.write(
        '    <thead><tr><th>Severity</th><th>Rule</th><th>Location</th><th>Message</th></tr></thead>\n',
      );
      buf.write('    <tbody>\n');
      for (final entry in byRule.entries) {
        for (final issue in entry.value) {
          buf.write(_issueRow(issue));
        }
      }
      buf.write('    </tbody>\n');
      buf.write('  </table>\n');
    }
    buf.write('</div>\n');
    return buf.toString();
  }

  String _topIssues(Report r) {
    if (r.issues.isEmpty) return '';
    final sorted = [...r.issues]
      ..sort((a, b) {
        final s = b.severity.index.compareTo(a.severity.index);
        if (s != 0) return s;
        return a.filePath.compareTo(b.filePath);
      });
    final top = sorted.take(10).toList();

    final buf = StringBuffer();
    buf.write('<div class="card">\n');
    buf.write(
      '  <h2><span class="num">4</span> Top issues to fix first</h2>\n',
    );
    buf.write(
      '  <p class="lead">Ten highest-severity findings — start here.</p>\n',
    );
    buf.write('  <ol class="top-list">\n');
    for (final issue in top) {
      final rel = p.relative(issue.filePath, from: projectRoot);
      buf.write('    <li>\n');
      buf.write('      <div class="top-head">');
      buf.write(
        '<span class="pill ${_pillClass(issue.severity)}">${issue.severity.label}</span> ',
      );
      buf.write('<code class="path">${_esc(rel)}:${issue.line}</code>');
      buf.write('</div>\n');
      buf.write('      <div class="top-msg">${_esc(issue.message)}</div>\n');
      if (issue.codeSnippet != null && issue.codeSnippet!.isNotEmpty) {
        buf.write('      <pre>${_esc(issue.codeSnippet!)}</pre>\n');
      }
      if (issue.suggestion != null && issue.suggestion!.isNotEmpty) {
        buf.write(
          '      <div class="top-fix"><strong>Fix:</strong> ${_esc(issue.suggestion!)}</div>\n',
        );
      }
      buf.write('    </li>\n');
    }
    buf.write('  </ol>\n');
    buf.write('</div>\n');
    return buf.toString();
  }

  String _appendix(Report r) {
    final counts = _countBySeverity(r.issues);
    return '''
<div class="card">
  <h2><span class="num">5</span> Appendix — scan inventory</h2>
  <div class="grid2">
    <div>
      <h3>Stats</h3>
      <ul class="tight">
        <li>Files scanned: <strong>${r.filesScanned}</strong></li>
        <li>Lines analysed: <strong>${r.linesAnalyzed}</strong></li>
        <li>Scan time: <strong>${r.elapsed.inMilliseconds} ms</strong></li>
        <li>Total findings: <strong>${r.issues.length}</strong></li>
      </ul>
    </div>
    <div>
      <h3>Findings by severity</h3>
      <ul class="tight">
        <li><span class="pill crit">CRITICAL</span> ${counts['critical']}</li>
        <li><span class="pill high">ERROR</span> ${counts['error']}</li>
        <li><span class="pill med">WARNING</span> ${counts['warning']}</li>
        <li><span class="pill low">INFO</span> ${counts['info']}</li>
      </ul>
    </div>
  </div>
  <h3>How scoring works</h3>
  <p class="footnote">
    Each category begins at 100 and loses points per finding (info −1, warning −2, error −5, critical −10).
    Scores floor at 0. The overall score is a weighted average that favours memory and security (1.5×)
    over UI and code quality (0.8×).
  </p>
</div>
''';
  }

  String _footer(Report r) {
    return '''
<footer class="footer">
  Generated by <code>flutter_audit</code> · ${r.timestamp.toLocal().toIso8601String()}
</footer>
''';
  }

  // --- helpers ----------------------------------------------------------

  String _issueRow(Issue issue) {
    final rel = p.relative(issue.filePath, from: projectRoot);
    final loc = '$rel:${issue.line}';
    final snippet = issue.codeSnippet != null && issue.codeSnippet!.isNotEmpty
        ? '<div class="snippet"><code>${_esc(issue.codeSnippet!)}</code></div>'
        : '';
    final suggestion = issue.suggestion != null && issue.suggestion!.isNotEmpty
        ? '<div class="suggest"><em>${_esc(issue.suggestion!)}</em></div>'
        : '';
    return '''
      <tr>
        <td><span class="pill ${_pillClass(issue.severity)}">${issue.severity.label}</span></td>
        <td><code>${_esc(issue.ruleId)}</code></td>
        <td><code class="path">${_esc(loc)}</code></td>
        <td>
          <div class="msg">${_esc(issue.message)}</div>
          $snippet
          $suggestion
        </td>
      </tr>
''';
  }

  String _summaryParagraph(Report r) {
    if (r.issues.isEmpty) {
      return 'Every registered rule passed on this codebase — no findings to report.';
    }
    final counts = _countBySeverity(r.issues);
    final parts = <String>[];
    if (counts['critical']! > 0) {
      parts.add('${counts['critical']} CRITICAL');
    }
    if (counts['error']! > 0) parts.add('${counts['error']} ERROR');
    if (counts['warning']! > 0) parts.add('${counts['warning']} WARNING');
    if (counts['info']! > 0) parts.add('${counts['info']} INFO');
    final scoreVerdict = _qualitative(r.scores.overall).toLowerCase();
    return 'Scanned <strong>${r.filesScanned}</strong> files (${r.linesAnalyzed} LOC). '
        'Found <strong>${r.issues.length}</strong> finding${r.issues.length == 1 ? '' : 's'} '
        '(${parts.join(', ')}). Overall score is <strong>${r.scores.overall} / 100 ($scoreVerdict)</strong>.';
  }

  Map<String, int> _countBySeverity(List<Issue> issues) {
    final m = {'info': 0, 'warning': 0, 'error': 0, 'critical': 0};
    for (final i in issues) {
      m[i.severity.name] = (m[i.severity.name] ?? 0) + 1;
    }
    return m;
  }

  String _grade(int score) {
    if (score >= 95) return 'A+';
    if (score >= 90) return 'A';
    if (score >= 85) return 'A-';
    if (score >= 80) return 'B+';
    if (score >= 75) return 'B';
    if (score >= 70) return 'B-';
    if (score >= 65) return 'C+';
    if (score >= 60) return 'C';
    if (score >= 55) return 'C-';
    if (score >= 50) return 'D';
    return 'F';
  }

  String _gradeClass(int score) {
    if (score >= 80) return 'a';
    if (score >= 65) return 'b';
    if (score >= 50) return 'c';
    return 'd';
  }

  String _qualitative(int score) {
    if (score >= 90) return 'EXCELLENT';
    if (score >= 80) return 'GOOD';
    if (score >= 70) return 'FAIR';
    if (score >= 50) return 'NEEDS WORK';
    return 'POOR';
  }

  String _pillClass(Severity s) => switch (s) {
    Severity.critical => 'crit',
    Severity.error => 'high',
    Severity.warning => 'med',
    Severity.info => 'low',
  };

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

const String _css = r'''
:root {
  --bg: #0f172a;
  --panel: #ffffff;
  --ink: #0f172a;
  --muted: #475569;
  --line: #e2e8f0;
  --soft: #f8fafc;
  --brand: #0d9488;
  --crit: #b91c1c;
  --crit-bg: #fef2f2;
  --high: #c2410c;
  --high-bg: #fff7ed;
  --med:  #b45309;
  --med-bg: #fffbeb;
  --low:  #1d4ed8;
  --low-bg: #eff6ff;
  --good: #15803d;
  --good-bg: #f0fdf4;
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font: 15px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  color: var(--ink);
  background: linear-gradient(180deg, #0b1220 0, #111c31 340px, #f1f5f9 340px, #f1f5f9 100%);
  min-height: 100vh;
}
.wrap { max-width: 1100px; margin: 0 auto; padding: 28px 24px 80px; }

header.cover { color: #fff; padding: 8px 0 28px; }
header.cover .eyebrow {
  font-size: 12px; letter-spacing: 0.18em; text-transform: uppercase;
  color: #5eead4; font-weight: 700;
}
header.cover h1 {
  font-size: 34px; line-height: 1.15; margin: 8px 0 6px;
  font-weight: 800; letter-spacing: -0.02em;
}
header.cover .sub { color: #cbd5e1; font-size: 14px; }
.meta-grid {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-top: 18px;
}
.meta {
  background: rgba(255,255,255,0.08);
  border: 1px solid rgba(255,255,255,0.12);
  border-radius: 10px; padding: 10px 12px;
}
.meta .k { font-size: 11px; color: #94a3b8; letter-spacing: 0.08em; text-transform: uppercase; }
.meta .v { font-size: 15px; font-weight: 700; color: #f8fafc; margin-top: 3px; }

.card {
  background: var(--panel);
  border-radius: 14px;
  box-shadow: 0 1px 2px rgba(15,23,42,0.04), 0 8px 30px rgba(15,23,42,0.06);
  padding: 22px 24px;
  margin: 18px 0;
  border: 1px solid var(--line);
}
h2 {
  font-size: 20px; margin: 0 0 4px; letter-spacing: -0.01em;
  display: flex; align-items: center; gap: 10px;
}
h2 .num {
  display: inline-flex; align-items: center; justify-content: center;
  width: 28px; height: 28px; border-radius: 8px;
  background: var(--brand); color: #fff; font-size: 13px; font-weight: 700;
}
h3 { font-size: 15px; margin: 18px 0 6px; color: var(--ink); }
h3.cat-h3 {
  display: flex; align-items: center; gap: 10px;
  margin-top: 26px; border-top: 1px solid var(--line); padding-top: 18px;
}
h3.cat-h3:first-of-type { border-top: 0; padding-top: 0; }
.cat-count {
  font-size: 12px; color: var(--muted); font-weight: 500;
}
p.lead { color: var(--muted); margin: 0 0 10px; }

.pill {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: 11px; font-weight: 700; letter-spacing: 0.04em;
}
.pill.crit { color: var(--crit); background: var(--crit-bg); }
.pill.high { color: var(--high); background: var(--high-bg); }
.pill.med  { color: var(--med);  background: var(--med-bg); }
.pill.low  { color: var(--low);  background: var(--low-bg); }
.pill.good { color: var(--good); background: var(--good-bg); }

.overall {
  display: flex; align-items: center; gap: 20px; margin: 6px 0 4px;
  padding: 16px 20px; background: var(--soft); border: 1px solid var(--line); border-radius: 12px;
}
.overall-num {
  font-size: 56px; font-weight: 800; letter-spacing: -0.03em;
  min-width: 110px; text-align: center;
}
.overall-num.a { color: #15803d; }
.overall-num.b { color: #1d4ed8; }
.overall-num.c { color: #b45309; }
.overall-num.d { color: #b91c1c; }
.overall-grade { font-size: 22px; font-weight: 800; letter-spacing: -0.01em; }
.overall-label { font-size: 12px; color: var(--muted); letter-spacing: 0.08em; text-transform: uppercase; }

.kpi-row { display: grid; grid-template-columns: repeat(4,1fr); gap: 10px; margin: 6px 0 4px; }
.kpi {
  background: var(--soft); border: 1px solid var(--line); border-radius: 10px; padding: 12px 14px;
}
.kpi .n { font-size: 24px; font-weight: 800; }
.kpi .n.crit { color: var(--crit); }
.kpi .n.high { color: var(--high); }
.kpi .n.med  { color: var(--med); }
.kpi .n.low  { color: var(--low); }
.kpi .lbl { font-size: 12px; color: var(--muted); }

.scores { display: grid; grid-template-columns: repeat(7, 1fr); gap: 8px; margin-top: 8px; }
.score {
  text-align: center; padding: 14px 4px; border: 1px solid var(--line);
  border-radius: 10px; background: var(--soft);
}
.score .grade { font-size: 26px; font-weight: 800; letter-spacing: -0.02em; }
.score .num-small { font-size: 11px; color: var(--muted); margin-top: 2px; }
.score .label { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; margin-top: 4px; }
.score.a .grade { color: #15803d; }
.score.b .grade { color: #1d4ed8; }
.score.c .grade { color: #b45309; }
.score.d .grade { color: #b91c1c; }

table { width: 100%; border-collapse: collapse; font-size: 14px; margin-top: 6px; }
th, td { text-align: left; padding: 9px 8px; border-bottom: 1px solid var(--line); vertical-align: top; }
th {
  color: var(--muted); font-weight: 600; font-size: 11px; letter-spacing: 0.04em;
  text-transform: uppercase; background: var(--soft);
}
td code, .path {
  font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12.5px;
  color: #0f172a; background: #f1f5f9; padding: 1px 5px; border-radius: 4px;
  word-break: break-all;
}
.msg { color: var(--ink); }
.snippet code {
  display: block; background: #0f172a; color: #e2e8f0; padding: 6px 10px;
  border-radius: 6px; margin-top: 6px; white-space: pre-wrap; word-break: break-all;
}
.suggest { margin-top: 4px; color: var(--muted); font-size: 13px; }

.top-list {
  margin: 6px 0 0; padding-left: 22px; counter-reset: top;
}
.top-list li {
  padding: 14px 0; border-top: 1px solid var(--line);
}
.top-list li:first-child { border-top: 0; padding-top: 4px; }
.top-head { display: flex; gap: 10px; align-items: center; }
.top-msg { margin-top: 4px; font-weight: 600; }
.top-fix { margin-top: 6px; color: var(--muted); font-size: 13.5px; }
pre {
  background: #0f172a; color: #e2e8f0; padding: 10px 14px; border-radius: 8px;
  overflow-x: auto; font: 12.5px/1.55 ui-monospace, Menlo, Consolas, monospace;
  margin: 6px 0 0;
}

.grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
ul.tight { margin: 6px 0 0; padding-left: 20px; }
ul.tight li { margin: 4px 0; }

.good-banner { color: var(--good); font-weight: 600; }

.footer {
  text-align: center; color: #94a3b8; font-size: 12px;
  margin-top: 24px; padding-top: 16px;
}
.footnote { color: var(--muted); font-size: 12.5px; margin: 6px 0 0; }

@media (max-width: 820px) {
  .meta-grid, .kpi-row { grid-template-columns: repeat(2, 1fr); }
  .scores { grid-template-columns: repeat(3, 1fr); }
  .grid2 { grid-template-columns: 1fr; }
}
@media print {
  body { background: #fff; }
  header.cover { color: #0f172a; }
  .card { box-shadow: none; }
}
''';
