import 'dart:convert';

import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/find_file.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/pubspec_lock.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/executables.dart';
import 'package:sip_cli/src/utils/list_ext.dart';
import 'package:yaml/yaml.dart';

class Package {
  Package(this._pubspecYaml);

  factory Package.nearest() {
    final yaml = pubspecYaml.nearest();

    if (yaml == null) {
      throw Exception('No pubspec.yaml file found');
    }

    return Package(yaml);
  }

  final String _pubspecYaml;

  String get pubspec => _pubspecYaml;

  String? _tool;
  bool? _isFlutter;
  bool get isFlutter {
    if (_isFlutter case final bool isFlutter) {
      return isFlutter;
    }

    final nestedLock = pubspecLock.findIn(path);
    final contents = findFile.retrieveContent(nestedLock ?? _pubspecYaml);

    return _isFlutter = contents?.contains('flutter') ?? false;
  }

  bool get isDart => !isFlutter;

  String? _name;
  String get name {
    if (_name case final name?) {
      return name;
    }

    final content = findFile.retrieveContent(this.pubspec);
    final pubspec = switch (content) {
      null => <String, dynamic>{},
      final content => jsonDecode(jsonEncode(loadYaml(content))),
    };

    final name = switch (pubspec) {
      {'name': final String name} => name,
      _ => null,
    };

    if (name == null) {
      throw Exception('No name found in pubspec.yaml');
    }

    return _name = name;
  }

  String get path => fs.path.dirname(_pubspecYaml);
  String get relativePath =>
      fs.path.relative(path, from: fs.currentDirectory.path);

  String get tool {
    if (_tool case final tool?) {
      return tool;
    }

    final executables = Executables.load();

    return _tool = switch (isFlutter) {
      true => executables.flutter ?? 'flutter',
      false => executables.dart ?? 'dart',
    };
  }

  bool get hasTests {
    return testFiles.isNotEmpty;
  }

  bool? _isPartOfWorkspace;
  bool get isPartOfWorkspace {
    if (_isPartOfWorkspace case final isPartOfWorkspace?) {
      return isPartOfWorkspace;
    }

    final content = findFile.retrieveContent(this.pubspec);

    final pubspec = switch (content) {
      null => <String, dynamic>{},
      final content => jsonDecode(jsonEncode(loadYaml(content))),
    };

    return _isPartOfWorkspace = switch (pubspec) {
      {'resolution': 'workspace'} => true,
      _ => false,
    };
  }

  bool? _isRootOfWorkspace;
  bool get isRootOfWorkspace {
    if (_isRootOfWorkspace case final isRootOfWorkspace?) {
      return isRootOfWorkspace;
    }

    final content = findFile.retrieveContent(this.pubspec);

    final pubspec = switch (content) {
      null => <String, dynamic>{},
      final content => jsonDecode(jsonEncode(loadYaml(content))),
    };

    return _isRootOfWorkspace = switch (pubspec) {
      {'workspace': Object()} => true,
      _ => false,
    };
  }

  bool shouldInclude({required bool dartOnly, required bool flutterOnly}) {
    if (dartOnly ^ flutterOnly) {
      if (dartOnly && isFlutter) {
        return false;
      } else if (flutterOnly && isDart) {
        return false;
      }
    }
    return true;
  }

  List<String> get testFiles {
    final glob = Glob('**/*_test.dart', recursive: true);
    final results = glob.listFileSystemSync(fs, followLinks: false, root: path);

    return [
      for (final file in results.whereType<File>())
        if (file.basename != fs.path.basename(_optimizedTestFilePath))
          file.path,
    ];
  }

  List<String> get testDirs {
    final dirs = <String>{};

    for (final file in testFiles) {
      dirs.add(fs.path.dirname(file));
    }

    return dirs.toList();
  }

  /// Splits the tests into groups of the given [args['slice']] size
  /// by separating [testDirs]
  List<List<String>> get testGroups {
    if (optimizedTestFile case final file?) {
      return [
        [fs.path.relative(file, from: path)],
      ];
    }

    final slice = args.getOrNull<int>('slice');

    final files = testDirs;

    if (slice != null) {
      return files.chunked(slice);
    }

    return [files];
  }

  String get _optimizedTestFilePath =>
      fs.path.join(path, 'test', '.test_optimizer.dart');

  String? _optimizedFile;
  String? get optimizedTestFile {
    if (_optimizedFile case final optimizedFile?) {
      return optimizedFile;
    }

    // we only optimize dart tests
    if (!isDart) return null;

    final files = testFiles;
    if (files.isEmpty) return null;

    final file = fs.file(_optimizedTestFilePath)..createSync(recursive: true);

    String test((int index, String file) data) {
      final (index, file) = data;
      return "group('$file', () { _i$index.main(); });";
    }

    String import((int index, String file) data) {
      final (index, file) = data;
      return "import '$file' as _i$index;";
    }

    final content =
        '''
import 'dart:async';

import 'package:test/test.dart';
${files.indexed.map(import).join('\n')}

void main() {
  ${files.indexed.map(test).join('\n  ')}
}
''';

    file.writeAsStringSync(content);

    return _optimizedFile = file.path;
  }

  void deleteOptimizedTestFile() {
    final file = fs.file(_optimizedTestFilePath);

    if (!file.existsSync()) return;

    file.deleteSync();
  }
}
