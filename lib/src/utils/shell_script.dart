import 'package:sip_cli/src/deps/platform.dart';

/// Builds shell commands that work on the current platform.
abstract final class ShellScript {
  static String changeDirectory(String directory) {
    if (platform.isWindows) {
      return 'cd /d "$directory" || exit /b 1';
    }

    return 'cd "$directory" || exit 1';
  }

  static String setVariable(String key, String value) {
    if (platform.isWindows) {
      return 'set "$key=$value"';
    }

    return 'export $key=$value';
  }

  static String get variableSeparator => platform.isWindows ? ' && ' : '\n';

  static String joinCommands(List<String> commands) {
    if (platform.isWindows) {
      return commands
          .expand((command) => command.split('\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join(' && ');
    }

    return commands.join('\n\n');
  }
}
