import 'dart:io';

import 'package:path/path.dart' as p;
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

/// Resolves Git Bash on Windows for native process spawning.
///
/// Plain `bash` resolves to WSL's stub (`System32\bash.exe`) when Dart starts
/// a native process, so Git for Windows must be located explicitly.
String? resolvePosixShellOnWindows({
  String? exepath,
  String? programFiles,
  String? programFilesX86,
  bool Function(String path)? exists,
}) {
  final windows = p.Context(style: p.Style.windows);
  bool check(String path) => exists?.call(path) ?? File(path).existsSync();

  final candidates = <String>[
    if (exepath != null) ...[
      windows.join(exepath, 'bash.exe'),
      windows.normalize(windows.join(exepath, '..', 'usr', 'bin', 'bash.exe')),
    ],
    if (programFiles != null) ...[
      windows.join(programFiles, 'Git', 'bin', 'bash.exe'),
      windows.join(programFiles, 'Git', 'usr', 'bin', 'bash.exe'),
    ],
    if (programFilesX86 != null) ...[
      windows.join(programFilesX86, 'Git', 'bin', 'bash.exe'),
      windows.join(programFilesX86, 'Git', 'usr', 'bin', 'bash.exe'),
    ],
  ];

  for (final candidate in candidates) {
    if (check(candidate)) return candidate;
  }

  return null;
}

/// Git Bash executable for the current process environment.
String posixShellOnWindows() {
  return resolvePosixShellOnWindows(
        exepath: Platform.environment['EXEPATH'],
        programFiles: Platform.environment['ProgramFiles'],
        programFilesX86: Platform.environment['ProgramFiles(x86)'],
      ) ??
      r'C:\Program Files\Git\bin\bash.exe';
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
