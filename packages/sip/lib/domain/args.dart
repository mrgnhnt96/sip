class Args {
  const Args({
    Map<String, ArgEntry>? args,
    List<String>? rest,
  })  : _args = args ?? const {},
        _rest = rest ?? const [];

  factory Args.parse(List<String> args) {
    // --no-<key> should be false under <key>
    // --<key> should be true under <key>
    // --key=value should be value under key
    final mapped = <String, ArgEntry>{};
    final rest = <String>[];

    void add(String rawKey, dynamic rawValue) {
      final key = switch (rawKey.split('--')) {
        [final key] => key,
        [_, final key] => key,
        _ => throw ArgumentError('Invalid key: $rawKey'),
      };

      final value = switch (rawValue) {
        final String string
            when string.contains(RegExp(r'^".*"$')) ||
                string.contains(RegExp(r"^'.*'$")) =>
          string.substring(1, string.length - 1),
        final value => value,
      };

      final entry = mapped[key];

      if (entry == null) {
        mapped[key] = ArgEntry(
          original: rawKey,
          key: key,
          value: value,
        );
        return;
      }

      // add to existing list of values
      // ignore: strict_raw_type
      if (entry.value case final Iterable list) {
        mapped[key] = ArgEntry(
          original: rawKey,
          key: key,
          value: list.followedBy([value]),
        );
        return;
      }

      // starts a new list
      mapped[key] = ArgEntry(
        original: rawKey,
        key: key,
        value: [entry.value, value],
      );
    }

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];

      if (!arg.startsWith('--')) {
        rest.add(arg);
        continue;
      }

      if (arg.split('=') case [final key, final value]) {
        add(key, value);
        continue;
      }

      if (arg.split('--no-') case [_, final key]) {
        mapped[key] = ArgEntry(
          original: arg,
          key: key,
          value: false,
        );
        continue;
      }

      final key = arg.substring(2);

      if (i + 1 < args.length) {
        if (args[i + 1] case final String value when !value.startsWith('--')) {
          add(key, value);
          i++;
          continue;
        }
      }

      mapped[key] = ArgEntry(
        original: arg,
        key: key,
        value: true,
      );
    }

    return Args(args: mapped, rest: rest);
  }

  final Map<String, ArgEntry> _args;
  final List<String> _rest;
  List<String> get rest => List.unmodifiable(_rest);
  List<String> get keys => _args.keys.toList();

  Map<String, bool> get flags {
    final flags = <String, bool>{};

    for (final entry in _args.values) {
      if (entry.value case final bool value) {
        flags[entry.key] = value;
      }
    }

    return Map.unmodifiable(flags);
  }

  Map<String, dynamic> get values => Map.unmodifiable(
        Map.fromEntries(
          _args.values.map((e) => e.toMapEntry()),
        ),
      );

  bool wasParsed(String key) => _args[key] != null;

  T get<T>(String key) {
    if (getOrNull<T>(key) case final T value) {
      return value;
    }

    throw ArgumentError('Key $key was not parsed as $T');
  }

  T? getOrNull<T>(String key) {
    if (!wasParsed(key)) {
      return null;
    }

    if (_args[key]?.value case final T value) {
      return value;
    }

    return null;
  }

  dynamic operator [](String key) => getOrNull<dynamic>(key);

  void operator []=(String key, dynamic value) {
    _args[key] = ArgEntry(
      original: key,
      key: key,
      value: value,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer();
    for (final entry in _args.entries) {
      sb.write('${entry.key}: ${entry.value}');
    }
    if (_rest.isNotEmpty) {
      sb.write('rest: ${_rest.join(' ')}');
    }
    return 'Args($sb)';
  }

  Args merge(Args other) {
    return Args(
      args: {..._args, ...other._args},
      rest: [..._rest, ...other._rest],
    );
  }

  String? original(String key) => _args[key]?.original;

  Iterable<String> toArgs() sync* {
    for (final entry in _args.values) {
      switch (entry.value) {
        case true:
          yield '--${entry.key}';
        case false:
          yield '--no-${entry.key}';
        case final List<dynamic> value:
          yield '--${entry.key}=${value.join(',')}';
        case final value:
          yield '--${entry.key}=$value';
      }
    }

    for (final arg in _rest) {
      yield arg;
    }
  }
}

class ArgEntry {
  const ArgEntry({
    required this.original,
    required this.key,
    required this.value,
  });

  final String? original;
  final String key;
  final dynamic value;

  MapEntry<String, dynamic> toMapEntry() => MapEntry(key, value);
}
