import 'package:meta/meta.dart';

@immutable
class ScriptEnv {
  const ScriptEnv({
    this.files = const [],
    this.commands = const [],
    this.vars = const {},
  });

  factory ScriptEnv.fromJson(Map<dynamic, dynamic> json) {
    final files = switch (json['files'] ?? json['file']) {
      final String file => [file],
      final List<dynamic> files => [
        for (final file in files)
          if (file case final String file)
            if (file.trim() case final file when file.isNotEmpty) file,
      ],
      _ => <String>[],
    };

    final commands = switch (json['commands'] ?? json['command']) {
      final String command => [command],
      final List<dynamic> commands => [
        for (final cmd in commands)
          if (cmd case final String cmd)
            if (cmd.trim() case final cmd when cmd.isNotEmpty) cmd,
      ],
      _ => <String>[],
    };

    final vars = switch (json['vars'] ?? json['variables']) {
      final Map<String, String> vars => vars,
      final Map<dynamic, dynamic> vars => {
        for (final MapEntry(:key, :value) in vars.entries)
          if (key case final String key)
            if (key.trim() case final key when key.isNotEmpty)
              key: switch (value) {
                int() => value.toString(),
                double() => value.toString(),
                bool() => value.toString(),
                String() => value,
                _ => '',
              },
      },
      _ => <String, String>{},
    };

    return ScriptEnv(files: files, commands: commands, vars: vars);
  }

  /// the file to source when running the script
  final List<String> files;

  /// The script to run to create the environment
  final List<String> commands;

  /// The environment variables to set when running the script
  final Map<String, String> vars;

  @override
  bool operator ==(Object other) {
    if (other is! ScriptEnv) return false;

    return files == other.files &&
        commands == other.commands &&
        vars == other.vars;
  }

  @override
  int get hashCode => Object.hashAll([files, commands, vars]);
}
