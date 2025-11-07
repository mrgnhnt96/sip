import 'dart:convert';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:platform/platform.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/process.dart';

class Find {
  const Find();

  static const _ignoreDirs = [
    '.git',
    'node_modules',
    'build',
    'dist',
    'out',
    'ios',
    'android',
    'windows',
    'macos',
    'linux',
    'web',
    'assets',
  ];

  Future<List<String>> file(
    String name, {
    required String workingDirectory,
    List<String> ignoreDirs = const [],
  }) {
    switch (platform) {
      case Platform(isLinux: true):
      case Platform(isMacOS: true):
        return _findLinux(
          name,
          workingDirectory: workingDirectory,
          file: true,
          ignoreDirs: ignoreDirs,
        );
      case Platform(isWindows: true):
        return _findWindows(
          name,
          workingDirectory: workingDirectory,
          ignoreDirs: ignoreDirs,
        );
      default:
        throw UnsupportedError(
          'Unsupported platform: ${platform.operatingSystem}',
        );
    }
  }

  Future<List<String>> _findLinux(
    String name, {
    required String workingDirectory,
    required bool file,
    List<String> ignoreDirs = const [],
  }) async {
    final ignore = <String>[
      for (final (index, dir) in _ignoreDirs.followedBy(ignoreDirs).indexed)
        [if (index != 0) '-o', '-path', '*/$dir'].join(' '),
    ];

    final type = file ? 'f' : 'd';

    final script =
        "find $workingDirectory \\( ${ignore.join(' ')} \\) -prune -o -name '$name' -type $type -print";

    final result = await process('bash', ['-c', script]);
    final stdout = await result.stdout.transform(utf8.decoder).join();
    return stdout.split('\n').where((e) => e.isNotEmpty).toList();
  }

  Future<List<String>> _findWindows(
    String name, {
    required String workingDirectory,
    List<String> ignoreDirs = const [],
  }) async {
    final files = Glob(
      fs.path.join(workingDirectory, '**', name),
      recursive: true,
    ).listFileSystemSync(fs, followLinks: false);

    return files.map((e) => e.path).toList();
  }

  Future<List<String>> filesInDirectory(
    String directory, {
    required String workingDirectory,
    List<String> ignoreDirs = const [],
  }) async {
    final directories = switch (platform) {
      Platform(isLinux: true) || Platform(isMacOS: true) => await _findLinux(
        directory,
        workingDirectory: workingDirectory,
        file: false,
        ignoreDirs: ignoreDirs,
      ),
      Platform(isWindows: true) => await _findWindowsDirectory(
        directory,
        workingDirectory: workingDirectory,
        ignoreDirs: ignoreDirs,
      ),
      _ => throw UnsupportedError(
        'Unsupported platform: ${platform.operatingSystem}',
      ),
    };

    final futures = <Future<List<String>>>[];

    for (final directory in directories) {
      futures.add(
        file('*', workingDirectory: directory, ignoreDirs: ignoreDirs),
      );
    }

    final results = await Future.wait(futures);
    return results.expand((e) => e).toList();
  }

  Future<List<String>> _findWindowsDirectory(
    String directory, {
    required String workingDirectory,
    List<String> ignoreDirs = const [],
  }) async {
    final directories = Glob(
      fs.path.join(workingDirectory, '**', directory),
      recursive: true,
    ).listFileSystemSync(fs).whereType<Directory>();

    return directories.map((e) => e.path).toList();
  }
}
