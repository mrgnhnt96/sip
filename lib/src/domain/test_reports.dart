import 'package:path/path.dart' as p;

/// Gives each `dart test`/`flutter test` run of one `sip test` its own
/// `--file-reporter` file.
///
/// One `sip test` can start several runs: one per package, per `--slice`,
/// and under `--experimental-bucket` per shard, per fallback and per
/// `--bucket-retry-failures` retry. Passed the same path, each would
/// overwrite the last. So the first run writes the path as given and every
/// later one inserts its number before the extension:
/// `test-results.json`, `test-results.1.json`, `test-results.2.json`, ...
///
/// A relative path is resolved against the directory sip was started in,
/// not the package directory each run executes in, so every report lands
/// where `--file-reporter` pointed.
class TestReports {
  TestReports();

  int _runs = 0;

  /// The `--file-reporter` argument for the next run, or `null` when
  /// [option] (the raw `<reporter>:<path>` value) is `null`.
  ///
  /// A value without a `:` is passed through untouched, so the test runner
  /// reports the malformed option itself.
  String? nextArgument(
    String? option, {
    required String cwd,
    required p.Context context,
  }) {
    if (option == null) return null;

    final separator = option.indexOf(':');
    if (separator == -1) return '--file-reporter $option';

    final reporter = option.substring(0, separator);
    final path = context.normalize(
      context.join(cwd, option.substring(separator + 1)),
    );

    final run = _runs++;
    final file = run == 0
        ? path
        : '${context.withoutExtension(path)}.$run${context.extension(path)}';

    return '--file-reporter ${_quote('$reporter:$file')}';
  }

  static String _quote(String value) =>
      value.contains(RegExp(r'\s')) ? '"$value"' : value;
}
