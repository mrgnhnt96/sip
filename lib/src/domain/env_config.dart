import 'package:sip_cli/src/deps/fs.dart';

class EnvConfig {
  const EnvConfig({
    this.commands = const [],
    this.files = const [],
    Map<String, String> variables = const {},
  }) : _variables = variables;

  const EnvConfig.empty()
    : commands = const [],
      files = const [],
      _variables = const {};

  final List<String> files;
  final List<String> commands;
  final Map<String, String> _variables;

  Map<String, String> get variables {
    final vars = {..._variables};

    final rawLines = <String>[];

    if (files case final files) {
      for (final path in files) {
        final file = fs.file(path);
        if (!file.existsSync()) {
          throw Exception('Env file $path not found');
        }

        rawLines.addAll(file.readAsLinesSync());
      }
    }

    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) continue;

      if (trimmed.contains('=')) {
        final parts = trimmed.split('=');
        if (parts.length != 2) continue;

        final [key, value] = parts;
        vars[key] = value;
        continue;
      }

      vars[trimmed] = '';
    }

    return Map.unmodifiable(vars);
  }
}
