import 'package:sip_cli/src/deps/scripts_yaml.dart';

/// The `(test)` section of `scripts.yaml`: settings for `sip test`.
class TestConfig {
  const TestConfig({required this.bucketSolo});

  factory TestConfig.load() {
    return TestConfig.fromJson(scriptsYaml.test() ?? {});
  }

  factory TestConfig.fromJson(Map<String, dynamic> json) {
    return TestConfig(bucketSolo: globList(json[bucketSoloKey]));
  }

  static const String bucketSoloKey = 'bucket-solo';

  /// Globs, relative to the package root, of test files that
  /// `--experimental-bucket` must never combine with other files.
  final List<String> bucketSolo;

  /// Reads a single glob or a list of globs, from `scripts.yaml` or from a
  /// repeated `--bucket-solo` flag, dropping anything that is not a string.
  static List<String> globList(Object? value) {
    final globs = switch (value) {
      final String glob => [glob],
      final Iterable<Object?> globs => globs,
      _ => const <Object?>[],
    };

    return [
      for (final glob in globs)
        // A glob never matches a leading `./`, but it is the natural way to
        // write a path relative to the package root.
        if (glob case final String glob) glob.replaceFirst(RegExp(r'^\./'), ''),
    ];
  }
}
