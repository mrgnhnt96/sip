import 'dart:async';

import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/domain/find_file.dart';
import 'package:sip_cli/src/domain/pubspec_lock.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/package.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  late Package pkg;
  late FindFile findFile;
  late PubspecLock pubspecLock;
  late ScriptsYaml scriptsYaml;

  setUp(() {
    findFile = _MockFindFile();
    pubspecLock = _MockPubspecLock();
    scriptsYaml = _MockScriptsYaml();

    pkg = Package('path/to/pubspec.yaml');

    when(() => findFile.retrieveContent(any())).thenReturn(null);
    when(() => pubspecLock.findIn(any())).thenReturn(null);
    when(() => scriptsYaml.executables()).thenReturn(null);
  });

  @isTest
  void test(String description, FutureOr<void> Function() fn) {
    testScoped(
      description,
      fn,
      findFile: () => findFile,
      pubspecLock: () => pubspecLock,
      scriptsYaml: () => scriptsYaml,
    );
  }

  group(Package, () {
    test('should return dart as the default tool', () {
      final tool = pkg.tool;

      expect(tool, 'dart');
      expect(pkg.isDart, isTrue);
      expect(pkg.isFlutter, isFalse);
    });

    test(
      'should return flutter as the tool if flutter is found in contents',
      () {
        when(() => findFile.retrieveContent(any())).thenReturn('flutter:');

        final tool = pkg.tool;

        expect(tool, 'flutter');
        expect(pkg.isDart, isFalse);
        expect(pkg.isFlutter, isTrue);
      },
    );

    test('should return custom dart executable if provided', () {
      when(() => scriptsYaml.executables()).thenReturn({'dart': 'custom_dart'});

      final tool = pkg.tool;

      expect(tool, 'custom_dart');
      expect(pkg.isDart, isTrue);
      expect(pkg.isFlutter, isFalse);
    });

    test('should return custom flutter executable if provided', () {
      when(() => findFile.retrieveContent(any())).thenReturn('flutter:');
      when(
        () => scriptsYaml.executables(),
      ).thenReturn({'flutter': 'custom_flutter'});

      final tool = pkg.tool;

      expect(tool, 'custom_flutter');
      expect(pkg.isDart, isFalse);
      expect(pkg.isFlutter, isTrue);
    });

    test('should return correct directory', () {
      final directory = pkg.path;

      expect(directory, 'path/to');
    });
  });
}

class _MockFindFile extends Mock implements FindFile {}

class _MockPubspecLock extends Mock implements PubspecLock {}

class _MockScriptsYaml extends Mock implements ScriptsYaml {}
