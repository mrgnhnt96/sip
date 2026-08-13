import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

/// Where something in `scripts.yaml` was written.
///
/// Lines and columns are 1-based, so `file:line:column` points at the same
/// place an editor and every other compiler-style diagnostic would.
class ScriptLocation {
  const ScriptLocation({
    required this.file,
    required this.line,
    required this.column,
  });

  final String file;
  final int line;
  final int column;

  Map<String, Object?> toJson() => {
    'file': file,
    'line': line,
    'column': column,
  };

  @override
  String toString() => '$file:$line:$column';
}

/// An index from a path of `scripts.yaml` keys to where it was written.
///
/// `scripts.yaml` is parsed into plain JSON everywhere else in sip, which
/// throws source spans away. This keeps them, so `sip validate` can emit
/// `scripts.yaml:12:3: error: ...` and `sip list --json` can tell a reader
/// where a script is declared.
///
/// Paths are lists of raw keys rather than a dotted string because script
/// keys may themselves contain dots.
class ScriptLocations {
  const ScriptLocations({
    required this.file,
    required Map<String, ScriptLocation> byPath,
  }) : _byPath = byPath;

  /// An index with nothing in it, for when `scripts.yaml` cannot be read.
  const ScriptLocations.empty()
    : file = '',
      _byPath = const <String, ScriptLocation>{};

  factory ScriptLocations.parse(String content, {required String file}) {
    final byPath = <String, ScriptLocation>{};

    ScriptLocation locationOf(SourceSpan span) => ScriptLocation(
      file: file,
      // source_span counts from zero; humans and editors count from one.
      line: span.start.line + 1,
      column: span.start.column + 1,
    );

    void walk(YamlNode node, List<String> path) {
      switch (node) {
        case final YamlMap map:
          for (final MapEntry(:key, :value) in map.nodes.entries) {
            if (key is! YamlScalar) continue;

            final childPath = [...path, '${key.value}'];
            byPath[_encode(childPath)] = locationOf(key.span);
            walk(value, childPath);
          }
        case final YamlList list:
          for (final (index, item) in list.nodes.indexed) {
            final childPath = [...path, indexKey(index)];
            byPath[_encode(childPath)] = locationOf(item.span);
            walk(item, childPath);
          }
        default:
          break;
      }
    }

    try {
      walk(loadYamlNode(content), const []);
    } on YamlException {
      // A file that does not parse has no locations to offer. Reporting the
      // parse error itself is `sip validate`'s job, not this index's.
      return ScriptLocations(file: file, byPath: const {});
    }

    return ScriptLocations(file: file, byPath: byPath);
  }

  final String file;
  final Map<String, ScriptLocation> _byPath;

  /// The path segment used for the [index]th entry of a list.
  static String indexKey(int index) => '[$index]';

  /// Where [path] was written, or null if it is not in the file.
  ScriptLocation? forPath(List<String> path) => _byPath[_encode(path)];

  /// Where [path] was written, falling back to its nearest declared ancestor.
  ///
  /// A command list item has its own location, but a caller that only knows
  /// the script it belongs to still gets pointed at the right script.
  ScriptLocation? nearest(List<String> path) {
    for (var end = path.length; end > 0; end--) {
      if (forPath(path.sublist(0, end)) case final location?) {
        return location;
      }
    }

    return null;
  }

  bool get isEmpty => _byPath.isEmpty;

  // Dots are legal in script keys, and spaces -- though rejected later --
  // still parse, so neither can separate path segments without colliding.
  // A null byte cannot appear in a YAML key at all.
  static String _encode(List<String> path) => path.join('\u0000');
}
