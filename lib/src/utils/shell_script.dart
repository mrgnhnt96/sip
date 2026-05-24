import 'dart:io';

import 'package:sip_cli/src/deps/platform.dart';

/// Whether script commands should use cmd.exe syntax on Windows.
///
/// Git Bash / MSYS (GitHub Actions `shell: bash` on Windows) sets [msystem];
/// those environments need POSIX shell syntax and `bash -c` execution.
bool usesCmdShell({required bool isWindows, String? msystem}) {
  if (!isWindows) return false;
  if (msystem != null && msystem.isNotEmpty) return false;
  return true;
}

/// Builds shell commands that work on the current platform.
abstract final class ShellScript {
  static bool get _usesCmdShell => usesCmdShell(
    isWindows: platform.isWindows,
    msystem: Platform.environment['MSYSTEM'],
  );

  /// Windows paths embedded in shell strings use forward slashes so
  /// backslash sequences (e.g. `\t` in `\test`) are not mangled by shells.
  static String _shellPath(String directory) {
    if (platform.isWindows) {
      return directory.replaceAll(r'\', '/');
    }

    return directory;
  }

  static String changeDirectory(String directory) {
    final path = _shellPath(directory);

    if (_usesCmdShell) {
      return 'cd /d "$path" || exit /b 1';
    }

    return 'cd "$path" || exit 1';
  }

  static String setVariable(String key, String value) {
    if (_usesCmdShell) {
      return 'set "$key=$value"';
    }

    return 'export $key=$value';
  }

  static String get variableSeparator => _usesCmdShell ? ' && ' : '\n';

  static String joinCommands(List<String> commands) {
    if (_usesCmdShell) {
      return commands
          .expand((command) => command.split('\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join(' && ');
    }

    return commands.join('\n\n');
  }
}
