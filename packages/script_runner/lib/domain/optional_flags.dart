/// A class to parse optional flags from a list of strings.
///
/// e.g. `['-f', 'file.txt', '--verbose', 'true']` would be parsed to `{'-f': '-f file.txt', '--verbose': '--verbose true'}`
class OptionalFlags {
  OptionalFlags(this._flags);

  final List<String> _flags;

  bool get isEmpty => _flags.isEmpty;
  bool get isNotEmpty => _flags.isNotEmpty;

  Map<String, String>? _parsed;

  void parse() {
    if (_parsed != null) return;
    final parsed = <String, String>{};

    List<String> consecutive = [];
    for (final flag in _flags) {
      if (flag.startsWith('-')) {
        if (consecutive.isNotEmpty) {
          parsed[consecutive.first] = consecutive.join(' ');
        }

        consecutive.clear();

        if (flag.contains('=')) {
          final split = flag.split('=');

          parsed[split.first] = flag;
          continue;
        }
      }

      consecutive.add(flag);
    }

    if (consecutive.isNotEmpty) {
      parsed[consecutive.first] = consecutive.join(' ');
    }

    _parsed = parsed;
  }

  String? operator [](String key) {
    parse();

    return _parsed![key];
  }
}
