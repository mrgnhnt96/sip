import 'package:sip_cli/src/deps/platform.dart';

/// Builds shell commands that work on the current platform.
abstract final class ShellScript {
  /// Windows paths embedded in shell strings use forward slashes so
  /// backslash sequences (e.g. `\t` in `\test`) are not mangled by
  /// Git Bash / MSYS wrappers around cmd.exe.
  static String _shellPath(String directory) {
    if (platform.isWindows) {
      return directory.replaceAll(r'\', '/');
    }

    return directory;
  }

  static String changeDirectory(String directory) {
    final path = _shellPath(directory);

    if (platform.isWindows) {
      return 'cd /d "$path" || exit /b 1';
    }

    return 'cd "$path" || exit 1';
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
