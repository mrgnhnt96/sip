import 'dart:async';

import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:sip_cli/src/domain/constrain_pubspec_versions.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  late MemoryFileSystem fs;
  late ConstrainPubspecVersions instance;

  setUp(() {
    fs = MemoryFileSystem();
    instance = const ConstrainPubspecVersions();
  });

  @isTest
  void test(String description, FutureOr<void> Function() fn) {
    testScoped(
      description,
      fn,
      fileSystem: () => fs,
      constrainPubspecVersions: () => instance,
    );
  }

  group(ConstrainPubspecVersions, () {
    group('#constrain', () {
      group('#dryRun', () {
        test('does not write to file', () {
          const content = '''
dependencies:
  foo: 1.2.3
''';

          final file = fs.file('pubspec.yaml')
            ..createSync(recursive: true)
            ..writeAsStringSync(content);

          final result = instance.constrain('pubspec.yaml', dryRun: true);

          expect(result, isTrue);
          expect(file.readAsStringSync(), content);
        });
      });
    });

    group('#constraint', () {
      group('returns null', () {
        test('when name is not a string', () {
          final result = instance.constraint(42, '1.2.3');

          expect(result, isNull);
        });

        test('when version is not a string', () {
          final result = instance.constraint('foo', 42);

          expect(result, isNull);
        });

        test('when version is path', () {
          const version = '''
  path: ../foo
''';

          final result = instance.constraint('foo', version);

          expect(result, isNull);
        });

        test('when version is git', () {
          const version = '''
  git:
    url: git://github.com/user/repo.git
''';

          final result = instance.constraint('foo', version);

          expect(result, isNull);
        });

        test('when version is hosted', () {
          const version = '''
  hosted:
    name: foo
    url: https://pub.dartlang.org
''';

          final result = instance.constraint('foo', version);

          expect(result, isNull);
        });

        test('when version is sdk', () {
          const version = '''
  sdk: '>=2.12.0 <3.0.0'
''';

          final result = instance.constraint('foo', version);

          expect(result, isNull);
        });
      });

      group('returns new constraint gracefully', () {
        test('when version number is normal', () {
          final result = instance.constraint('foo', '1.2.3');

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3 <2.0.0');
        });

        test('when version number has min', () {
          final result = instance.constraint('foo', '^1.2.3');

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3 <2.0.0');
        });

        test('when version constrained', () {
          final result = instance.constraint('foo', '>1.2.3 <1.2.4');

          expect(result, isNotNull);
          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3 <2.0.0');
        });

        test('when version number contains pre-release', () {
          final result = instance.constraint('foo', '1.2.3-dev.1');

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3-dev.1 <2.0.0');
        });

        test('when version number contains build', () {
          final result = instance.constraint('foo', '1.2.3+42');

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3+42 <2.0.0');
        });

        test('when version number contains pre-release and build', () {
          final result = instance.constraint('foo', '1.2.3-dev.1+42');

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3-dev.1+42 <2.0.0');
        });
      });

      group('bumps correct version', () {
        test('breaking before first major', () {
          final result = instance.constraint('foo', '0.1.2');

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=0.1.2 <0.2.0');
        });

        test('breaking after first major', () {
          final result = instance.constraint('foo', '1.2.3');

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3 <2.0.0');
        });

        test('major', () {
          final result = instance.constraint(
            'foo',
            '1.2.3',
            bump: VersionBump.major,
          );

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3 <2.0.0');
        });

        test('minor', () {
          final result = instance.constraint(
            'foo',
            '1.2.3',
            bump: VersionBump.minor,
          );

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3 <1.3.0');
        });

        test('patch', () {
          final result = instance.constraint(
            'foo',
            '1.2.3',
            bump: VersionBump.patch,
          );

          expect(result, isNotNull);

          final (:name, :version) = result!;

          expect(name, 'foo');
          expect(version, '>=1.2.3 <1.2.4');
        });
      });
    });

    group('#applyConstraintsTo', () {
      group('returns null', () {
        test('when dependencies are not provided', () {
          const content = '';

          final result = instance.applyConstraintsTo(content);

          expect(result, isNull);
        });

        test('when dependencies are not changed', () {
          const content = '''
dependencies:
  foo: ">=1.2.3 <2.0.0"
''';

          final result = instance.applyConstraintsTo(content);

          expect(result, isNull);
        });
      });

      group('runs successfully', () {
        test('when dependencies exist', () {
          const content = '''
dependencies:
  foo: 1.2.3

dev_dependencies:
  bar: 2.3.4
''';

          const expected = '''
dependencies:
  foo: ">=1.2.3 <2.0.0"

dev_dependencies:
  bar: 2.3.4
''';

          final result = instance.applyConstraintsTo(content);

          expect(result, isNotNull);
          expect(result, expected);
        });

        test('when dev_dependencies exist', () {
          const content = '''
dev_dependencies:
  foo: 1.2.3

dependencies:
  bar: 2.3.4
''';

          const expected = '''
dev_dependencies:
  foo: ">=1.2.3 <2.0.0"

dependencies:
  bar: ">=2.3.4 <3.0.0"
''';

          final result = instance.applyConstraintsTo(
            content,
            additionalKeys: ['dev_dependencies'],
          );

          expect(result, isNotNull);
          expect(result, expected);
        });
      });

      test('ignores invalid dependencies', () {
        const content = '''
dependencies:
  deku: 1.2.3
  link:
    path: ../bar
  zelda:
    git:
      url: git://github.com/user/repo.git
  ganon:
    hosted:
      name: qux
      url: https://pub.dartlang.org
  hyrule:
    sdk: '>=2.12.0 <3.0.0'
  triforce: '>1.2.3 <2.0.0'
  epona: ">=1.2.3 <2.0.0"
''';

        const expected = '''
dependencies:
  deku: ">=1.2.3 <2.0.0"
  link:
    path: ../bar
  zelda:
    git:
      url: git://github.com/user/repo.git
  ganon:
    hosted:
      name: qux
      url: https://pub.dartlang.org
  hyrule:
    sdk: '>=2.12.0 <3.0.0'
  triforce: ">=1.2.3 <2.0.0"
  epona: ">=1.2.3 <2.0.0"
''';

        final result = instance.applyConstraintsTo(content);

        expect(result, isNotNull);
        expect(result, expected);
      });

      test('applies to only certain packages', () {
        final packages = [('foo', null), ('bar', null)];

        const content = '''
dependencies:
  foo: 1.2.3
  bar: 2.3.4
  baz: 3.4.5
''';

        const expected = '''
dependencies:
  foo: ">=1.2.3 <2.0.0"
  bar: ">=2.3.4 <3.0.0"
  baz: 3.4.5
''';

        final result = instance.applyConstraintsTo(content, packages: packages);

        expect(result, isNotNull);
        expect(result, expected);
      });

      test('applies to only certain packages with version', () {
        final packages = [('foo', '4.5.6'), ('bar', '5.6.7')];

        const content = '''
dependencies:
  foo: 1.2.3
  bar: 2.3.4
  baz: 3.4.5
''';

        const expected = '''
dependencies:
  foo: ">=4.5.6 <5.0.0"
  bar: ">=5.6.7 <6.0.0"
  baz: 3.4.5
''';

        final result = instance.applyConstraintsTo(content, packages: packages);

        expect(result, isNotNull);
        expect(result, expected);
      });

      test('pins dependencies', () {
        const content = '''
dependencies:
  foo: ">=1.2.3 <2.0.0"
  bar: ^2.3.4
  baz: 3.4.5
''';

        const expected = '''
dependencies:
  foo: 1.2.3
  bar: 2.3.4
  baz: 3.4.5
''';

        final result = instance.applyConstraintsTo(content, pin: true);

        expect(result, isNotNull);
        expect(result, expected);
      });

      test('unpins dependencies', () {
        const content = '''
dependencies:
  foo: ">=1.2.3 <2.0.0"
  bar: ^2.3.4
  baz: 3.4.5
''';

        const expected = '''
dependencies:
  foo: ^1.2.3
  bar: ^2.3.4
  baz: ^3.4.5
''';

        final result = instance.applyConstraintsTo(content, pin: false);

        expect(result, isNotNull);
        expect(result, expected);
      });

      test('pins dependencies with specified package and version', () {
        const content = '''
dependencies:
  foo: ">=1.2.3 <2.0.0"
  bar: ^2.3.4
  baz: 3.4.5
''';

        const expected = '''
dependencies:
  foo: 1.2.3
  bar: 2.3.4
  baz: 3.4.5
''';

        final result = instance.applyConstraintsTo(
          content,
          packages: [('foo', '1.2.3'), ('bar', '2.3.4')],
          pin: true,
        );

        expect(result, isNotNull);
        expect(result, expected);
      });

      test('unpins dependencies with specified package', () {
        const content = '''
dependencies:
  foo: ">=1.2.3 <2.0.0"
  bar: ^2.3.4
  baz: 3.4.5
''';

        const expected = '''
dependencies:
  foo: ^1.2.3
  bar: ^2.3.4
  baz: 3.4.5
''';

        final result = instance.applyConstraintsTo(
          content,
          packages: [('foo', null), ('bar', null)],
          pin: false,
        );

        expect(result, isNotNull);
        expect(result, expected);
      });

      test('unpins dependencies with specified package and version', () {
        const content = '''
dependencies:
  foo: ">=1.2.3 <2.0.0"
  bar: ^2.3.4
  baz: 3.4.5
''';

        const expected = '''
dependencies:
  foo: ^2.3.4
  bar: ^3.4.5
  baz: 3.4.5
''';

        final result = instance.applyConstraintsTo(
          content,
          packages: [('foo', '2.3.4'), ('bar', '3.4.5')],
          pin: false,
        );

        expect(result, isNotNull);
        expect(result, expected);
      });
    });
  });
}
