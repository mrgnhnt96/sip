class Args {
  const Args({
    Map<String, dynamic>? args,
    List<String>? rest,
    List<String>? path,
    Map<String, dynamic>? abbr,
  }) : _args = args ?? const {},
       _rest = rest ?? const [],
       _path = path ?? const [],
       _abbr = abbr ?? const {};

  factory Args.parse(List<String> args) {
    // --no-<key> should be false under <key>
    // --<key> should be true under <key>
    // --key=value should be value under key
    final mapped = <String, dynamic>{};
    final rest = <String>[];
    final path = <String>[];
    final abbr = <String, dynamic>{};

    void add(String rawKey, dynamic rawValue) {
      final key = switch (rawKey.split('--')) {
        [final key] => key,
        [_, final key] => key,
        _ => throw ArgumentError('Invalid key: $rawKey'),
      };

      var value = switch (rawValue) {
        final String string
            when string.contains(RegExp(r'^".*"$')) ||
                string.contains(RegExp(r"^'.*'$")) =>
          string.substring(1, string.length - 1),
        final value => value,
      };

      if (int.tryParse('$value') case final int v) {
        value = v;
      } else if (double.tryParse('$value') case final double v) {
        value = v;
      } else {
        value = switch (value) {
          'true' => true,
          'false' => false,
          'null' => null,
          _ => value,
        };
      }

      if (mapped[key] case null) {
        mapped[key] = value;
        return;
      }

      // add to existing list of values
      // ignore: strict_raw_type
      if (mapped[key] case final Iterable list) {
        mapped[key] = list.followedBy([value]);
        return;
      }

      // starts a new list
      mapped[key] = [mapped[key], value];
    }

    var pathIsParsed = false;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];

      if (!arg.startsWith('-')) {
        if (pathIsParsed) {
          rest.add(arg);
        } else {
          path.add(arg);
        }
        continue;
      }

      if (!pathIsParsed) {
        pathIsParsed = true;
      }

      if (arg.startsWith(RegExp(r'-\w+'))) {
        var key = arg.substring(1);
        String? value;

        if (key.split('=') case [final k, final v]) {
          key = k;
          value = v;
        } else if (i + 1 < args.length) {
          value = switch (args[i + 1]) {
            final String value when !value.startsWith('-') => value,
            _ => null,
          };
        }

        final keys = key.split('');

        if (value != null) {
          abbr[keys.removeLast()] = value;
          i++;
        }

        for (final alias in keys) {
          abbr[alias] = true;
        }

        continue;
      }

      if (arg.split('=') case [final key, final value]) {
        add(key, value);
        continue;
      }

      if (arg.split('--no-') case [_, final key]) {
        mapped[key] = false;
        continue;
      }

      final key = arg.substring(2);

      if (i + 1 < args.length) {
        if (args[i + 1] case final String value when !value.startsWith('-')) {
          add(key, value);
          i++;
          continue;
        }
      }

      // Standalone flag e.g. --flag
      mapped[key] = true;
    }

    return Args(args: mapped, rest: rest, path: path, abbr: abbr);
  }

  final Map<String, dynamic> _args;
  final List<String> _rest;
  final List<String> _path;
  final Map<String, dynamic> _abbr;

  List<String> get rest => List.unmodifiable(_rest);
  List<String> get path => List.unmodifiable(_path);
  List<String> get keys => _args.keys.toList();
  Map<String, dynamic> get abbrs => Map.unmodifiable(_abbr);
  Map<String, dynamic> get values => Map.unmodifiable(_args);

  Map<String, bool> get flags {
    final flags = <String, bool>{};

    for (final entry in _args.entries) {
      if (entry.value case final bool value) {
        flags[entry.key] = value;
      }
    }

    return Map.unmodifiable(flags);
  }

  bool wasParsed(String key, {List<String>? aliases, String? abbr}) {
    for (final key in [key, ...?aliases]) {
      if (_args[key] case Object()) {
        return true;
      }
    }

    if (abbr?.substring(0, 1) case final String abbr) {
      if (_abbr[abbr] case Object()) {
        return true;
      }
    }

    return false;
  }

  T get<T extends Object>(
    String key, {
    List<String> aliases = const [],
    String? abbr,
  }) {
    final result = getOrNull(key, aliases: aliases, abbr: abbr);
    if (result == null) {
      throw ArgumentError('Flag/option "$key" was not parsed');
    }

    if (result case final T value) {
      return value;
    }

    throw ArgumentError('Flag/option "$key" was not parsed as $T: $result');
  }

  T? getOrNull<T extends Object>(
    String key, {
    List<String>? aliases,
    String? abbr,
  }) {
    if (!wasParsed(key, aliases: aliases, abbr: abbr)) {
      return null;
    }

    for (final key in [key, ...?aliases]) {
      if (_args[key] case final T value) {
        return value;
      }
    }

    if (abbr?.substring(0, 1) case final String abbr) {
      if (_abbr[abbr] case final T value) {
        return value;
      }
    }

    return null;
  }

  dynamic operator [](String key) => getOrNull(key);

  @override
  String toString() {
    final sb = StringBuffer();
    for (final entry in _args.entries) {
      sb.write('${entry.key}: ${entry.value} ');
    }
    if (_rest.isNotEmpty) {
      sb.write('rest: ${_rest.join(' ')}');
    }
    return 'Args(${sb.toString().trim()})';
  }
}
