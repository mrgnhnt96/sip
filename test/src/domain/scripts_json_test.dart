import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sip_cli/src/domain/script_locations.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/domain/scripts_json.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group('scriptsConfigToJson', () {
    const yaml = r'''
(executables):
  dart: fvm dart

(variables):
  out: build/out

_private: echo private

format:
  (description): Format everything
  (aliases): [f]
  (command): ${{ dart }} format .

build_runner:
  _: ${{ dart }} run build_runner
  build: ${{ build_runner._ }} build

group_only:
  child: echo child

concurrent:
  (command):
    - (+) echo one
    - (+) echo two
''';

    FileSystem createFs() {
      final fs = MemoryFileSystem.test();
      fs.file('/scripts.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(yaml);

      return fs;
    }

    Map<String, Object?> scriptWithKey(
      Map<String, Object?> payload,
      String key,
    ) {
      final scripts = (payload['scripts']! as List)
          .cast<Map<String, Object?>>();

      return scripts.firstWhere(
        (e) => e['key'] == key,
        orElse: () => fail('no script with key "$key"'),
      );
    }

    Map<String, Object?> build() => scriptsConfigToJson(
      ScriptsConfig.load(),
      locations: ScriptLocations.parse(yaml, file: '/scripts.yaml'),
    );

    testScoped(
      'flattens nested scripts under dotted keys',
      fileSystem: createFs,
      () {
        final payload = build();
        final keys = (payload['scripts']! as List)
            .cast<Map<String, Object?>>()
            .map((e) => e['key'])
            .toList();

        expect(
          keys,
          containsAll([
            'format',
            'build_runner',
            'build_runner._',
            'build_runner.build',
            'group_only',
            'group_only.child',
          ]),
        );
      },
    );

    testScoped('carries the payload version', fileSystem: createFs, () {
      expect(build()['version'], scriptsJsonVersion);
    });

    testScoped('reports metadata for a script', fileSystem: createFs, () {
      final format = scriptWithKey(build(), 'format');

      expect(format['name'], 'format');
      expect(format['path'], ['format']);
      expect(format['parent'], isNull);
      expect(format['description'], 'Format everything');
      expect(format['aliases'], ['f']);
      expect(format['private'], isFalse);
      expect(format['runnable'], isTrue);
      expect(format['bail'], isFalse);
    });

    testScoped('resolves references and executables', fileSystem: createFs, () {
      final build = scriptWithKey(
        scriptsConfigToJson(
          ScriptsConfig.load(),
          locations: ScriptLocations.parse(yaml, file: '/scripts.yaml'),
        ),
        'build_runner.build',
      );

      // The raw command still holds the reference...
      expect(build['commands'], [r'${{ build_runner._ }} build']);

      // ...and the resolved one is what actually runs, with `(executables)`
      // applied. This is the difference between reading scripts.yaml and
      // knowing what the script does.
      final resolved = (build['resolved']! as List)
          .cast<Map<String, Object?>>()
          .map((e) => e['command'])
          .toList();

      expect(resolved, ['fvm dart run build_runner build']);
      expect(build['resolveError'], isNull);
    });

    testScoped('marks private scripts', fileSystem: createFs, () {
      expect(scriptWithKey(build(), '_private')['private'], isTrue);
      expect(scriptWithKey(build(), 'build_runner._')['private'], isTrue);
      expect(scriptWithKey(build(), 'format')['private'], isFalse);
    });

    testScoped(
      'marks a group with no command as not runnable',
      fileSystem: createFs,
      () {
        final group = scriptWithKey(build(), 'group_only');

        expect(group['runnable'], isFalse);
        expect(group['commands'], isEmpty);
        // Nothing to resolve, so nothing is reported either way.
        expect(group['resolved'], isNull);
        expect(group['resolveError'], isNull);
      },
    );

    testScoped(
      'reports concurrency per resolved command',
      fileSystem: createFs,
      () {
        final concurrent =
            (scriptWithKey(build(), 'concurrent')['resolved']! as List)
                .cast<Map<String, Object?>>();

        expect(concurrent.map((e) => e['command']), ['echo one', 'echo two']);
        expect(concurrent.every((e) => e['concurrent'] == true), isTrue);
      },
    );

    testScoped(
      'includes where each script is declared',
      fileSystem: createFs,
      () {
        final location =
            scriptWithKey(build(), 'format')['location']!
                as Map<String, Object?>;

        expect(location['file'], '/scripts.yaml');
        expect(location['line'], 9);
      },
    );

    testScoped(
      'omits resolution entirely when asked',
      fileSystem: createFs,
      () {
        final payload = scriptsConfigToJson(
          ScriptsConfig.load(),
          locations: ScriptLocations.parse(yaml, file: '/scripts.yaml'),
          resolve: false,
        );

        final format = scriptWithKey(payload, 'format');

        expect(format.containsKey('resolved'), isFalse);
        expect(format.containsKey('resolveError'), isFalse);
        expect(format['commands'], isNotEmpty);
      },
    );

    testScoped(
      'only limits the listing to the given scripts',
      fileSystem: createFs,
      () {
        final config = ScriptsConfig.load();

        final payload = scriptsConfigToJson(
          config,
          locations: ScriptLocations.parse(yaml, file: '/scripts.yaml'),
          only: [
            config.find(['format'])!,
          ],
        );

        expect(
          (payload['scripts']! as List).single,
          containsPair('key', 'format'),
        );
      },
    );

    testScoped(
      'passes executables and variables through',
      fileSystem: createFs,
      () {
        final payload = scriptsConfigToJson(
          ScriptsConfig.load(),
          locations: ScriptLocations.parse(yaml, file: '/scripts.yaml'),
          executables: const {'dart': 'fvm dart', 'flutter': null},
          variables: const {'out': 'build/out', 'unset': null},
        );

        // Nulls are dropped so a reader never has to distinguish "absent" from
        // "present but null".
        expect(payload['executables'], {'dart': 'fvm dart'});
        expect(payload['variables'], {'out': 'build/out'});
      },
    );
  });
}
