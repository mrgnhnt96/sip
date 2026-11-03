import 'dart:convert';

import 'package:file/file.dart';
import 'package:sip_cli/src/deps/fs.dart';

/// Turns `--file-reporter <reporter>:<path>` into one report at `<path>`,
/// however many `dart test`/`flutter test` runs one `sip test` starts.
///
/// One `sip test` can start several runs: one per package, per `--slice`,
/// and under `--experimental-bucket` per shard and per fallback. Each run
/// writes its own temporary file ([nextArgument]), and [write] merges them
/// into `<path>` once everything has run, so the report holds the same
/// results sip reports:
///
///  - Tests from files a bucket fallback threw away ([discard]) are left
///    out, and a run the fallback replaced outright ([discardRun]) is left
///    out whole; the fallback's re-run of those files stands in for them.
///  - `--bucket-retry-failures` retries get no report at all (see
///    `TesterMixin.createTestCommand`): sip keeps the combined result.
///
/// A `json` report is merged into one event stream (see [mergeJson]). Any
/// other reporter's output is concatenated in run order.
///
/// A relative `<path>` is resolved against the directory sip was started
/// in, not the package directory each run executes in.
class TestReports {
  TestReports();

  ({String reporter, String path})? _target;
  Directory? _tempDir;
  final _runs = <String>[];
  final _discarded = <String, Set<String>>{};
  final _discardedRuns = <String>{};

  /// The `--file-reporter` argument for the next run, writing to a file of
  /// its own, or `null` when [option] (the raw `<reporter>:<path>` value)
  /// is `null`. [reportFile] receives that file, to pass to [discard].
  ///
  /// A value without a `:` is passed through untouched, so the test runner
  /// reports the malformed option itself.
  String? nextArgument(
    String? option, {
    void Function(String reportFile)? reportFile,
  }) {
    if (option == null) return null;

    final separator = option.indexOf(':');
    if (separator == -1) return '--file-reporter $option';

    final reporter = option.substring(0, separator);
    _target ??= (
      reporter: reporter,
      path: fs.path.normalize(
        fs.path.join(fs.currentDirectory.path, option.substring(separator + 1)),
      ),
    );

    final dir = _tempDir ??= fs.systemTempDirectory.createTempSync(
      'sip_test_reports_',
    );
    final file = fs.path.join(dir.path, 'run_${_runs.length}.report');
    _runs.add(file);
    reportFile?.call(file);

    return '--file-reporter ${_quote('$reporter:$file')}';
  }

  /// Leaves the tests of [files] (package-relative, as bucketed) out of the
  /// run that wrote [reportFile].
  void discard(String reportFile, Iterable<String> files) {
    (_discarded[reportFile] ??= {}).addAll(
      files.map((file) => file.replaceAll(r'\', '/')),
    );
  }

  /// Leaves the run that wrote [reportFile] out of the report entirely.
  void discardRun(String reportFile) => _discardedRuns.add(reportFile);

  /// Writes the merged report to the `--file-reporter` path and removes the
  /// per-run files. Does nothing when no run had a report.
  void write() {
    final target = _target;
    final dir = _tempDir;
    if (target == null || dir == null) return;

    final runs = [
      for (final run in _runs)
        if (fs.file(run) case final file
            when file.existsSync() && !_discardedRuns.contains(run))
          (content: file.readAsStringSync(), discarded: _discarded[run] ?? {}),
    ];

    final merged = switch (target.reporter) {
      'json' => mergeJson(runs),
      _ => runs.map((run) => run.content).join(),
    };

    fs.file(target.path)
      ..createSync(recursive: true)
      ..writeAsStringSync(merged);

    dir.deleteSync(recursive: true);
    _tempDir = null;
    _runs.clear();
    _discarded.clear();
    _discardedRuns.clear();
  }

  /// Merges the `json` reporter output of several runs into one stream.
  ///
  /// Every run numbers its suites, groups and tests from 0, so each run's
  /// ids are moved past the previous run's. The merged stream opens with
  /// one `start` and one `allSuites`, and closes with one `done`. Tests
  /// whose name belongs to a run's `discarded` files -- a bucket wrapper
  /// names each file's group after the file -- are dropped together with
  /// everything they reported.
  static String mergeJson(
    List<({String content, Set<String> discarded})> runs,
  ) {
    Object? start;
    var suites = 0;
    var success = true;
    Object? time = 0;
    var offset = 0;
    final events = <Object?>[];

    for (final run in runs) {
      var maxId = -1;
      var keptFailure = false;
      var runFailed = false;
      final dropped = <Object?>{};

      bool isDiscarded(Object? name) =>
          name is String &&
          run.discarded.any(
            (file) => name == file || name.startsWith('$file '),
          );

      int shift(Object? id) {
        final value = id! as int;
        if (value > maxId) maxId = value;
        return value + offset;
      }

      for (final line in const LineSplitter().convert(run.content)) {
        final Object? decoded;
        try {
          decoded = jsonDecode(line);
        } on FormatException {
          // A run killed mid-write (bail) can leave a partial last line.
          continue;
        }
        if (decoded is! Map<String, Object?>) continue;
        final event = decoded;

        switch (event['type']) {
          case 'start':
            start ??= event;
            continue;
          case 'allSuites':
            suites += switch (event['count']) {
              final int count => count,
              _ => 0,
            };
            continue;
          case 'done':
            runFailed = event['success'] == false;
            time = event['time'] ?? time;
            continue;
        }

        if (event case {
          'type': 'testStart',
          'test': {'id': final id, 'name': final name},
        } when isDiscarded(name)) {
          dropped.add(id);
          continue;
        }

        if (event case {
          'type': 'group',
          'group': {'name': final name},
        } when isDiscarded(name)) {
          continue;
        }

        if (event['testID'] case final id? when dropped.contains(id)) {
          continue;
        }

        if (event case {'type': 'testDone', 'result': 'failure' || 'error'}) {
          keptFailure = true;
        }

        events.add(_shiftIds(event, shift));
      }

      // A run that lost results to a fallback failed for them; what is
      // left of it only fails the merged run if a kept test failed.
      success &= run.discarded.isEmpty ? !runFailed : !keptFailure;
      offset += maxId + 1;
    }

    return [
      ?start,
      {'type': 'allSuites', 'count': suites, 'time': 0},
      ...events,
      {'type': 'done', 'success': success, 'time': time},
    ].map(jsonEncode).map((line) => '$line\n').join();
  }

  static const _idKeys = {'id', 'suiteID', 'parentID', 'testID'};

  static Object? _shiftIds(Object? value, int Function(Object?) shift) {
    return switch (value) {
      final Map<String, Object?> map => {
        for (final MapEntry(:key, value: entry) in map.entries)
          key: switch (key) {
            _ when _idKeys.contains(key) && entry is int => shift(entry),
            'groupIDs' when entry is List => [
              for (final id in entry)
                if (id is int) shift(id) else id,
            ],
            _ => _shiftIds(entry, shift),
          },
      },
      final List<Object?> list => [
        for (final item in list) _shiftIds(item, shift),
      ],
      _ => value,
    };
  }

  static String _quote(String value) =>
      value.contains(RegExp(r'\s')) ? '"$value"' : value;
}
