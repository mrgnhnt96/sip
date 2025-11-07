import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:test/test.dart';

void main() {
  late DetermineFlutterOrDart determineFlutterOrDart;
  late FindFile mockFindFile;
  late PubspecLock mockPubspecLock;
  late ScriptsYaml mockScriptsYaml;

  setUp(() {
    mockFindFile = _MockFindFile();
    mockPubspecLock = _MockPubspecLock();
    mockScriptsYaml = _MockScriptsYaml();

    determineFlutterOrDart = DetermineFlutterOrDart(
      pubspecYaml: 'path/to/pubspec.yaml',
      pubspecLock: mockPubspecLock,
      findFile: mockFindFile,
      scriptsYaml: mockScriptsYaml,
    );
  });

  group(DetermineFlutterOrDart, () {
    test('should return dart as the default tool', () {
      when(() => mockFindFile.retrieveContent(any())).thenReturn(null);
      when(() => mockPubspecLock.findIn(any())).thenReturn(null);
      when(() => mockScriptsYaml.executables()).thenReturn(null);

      final tool = determineFlutterOrDart.tool();

      expect(tool, 'dart');
      expect(determineFlutterOrDart.isDart, isTrue);
      expect(determineFlutterOrDart.isFlutter, isFalse);
    });

    test(
      'should return flutter as the tool if flutter is found in contents',
      () {
        when(() => mockFindFile.retrieveContent(any())).thenReturn('flutter:');
        when(() => mockPubspecLock.findIn(any())).thenReturn(null);
        when(() => mockScriptsYaml.executables()).thenReturn(null);

        final tool = determineFlutterOrDart.tool();

        expect(tool, 'flutter');
        expect(determineFlutterOrDart.isDart, isFalse);
        expect(determineFlutterOrDart.isFlutter, isTrue);
      },
    );

    test('should return custom dart executable if provided', () {
      when(() => mockFindFile.retrieveContent(any())).thenReturn(null);
      when(() => mockPubspecLock.findIn(any())).thenReturn(null);
      when(
        () => mockScriptsYaml.executables(),
      ).thenReturn({'dart': 'custom_dart'});

      final tool = determineFlutterOrDart.tool();

      expect(tool, 'custom_dart');
      expect(determineFlutterOrDart.isDart, isTrue);
      expect(determineFlutterOrDart.isFlutter, isFalse);
    });

    test('should return custom flutter executable if provided', () {
      when(() => mockFindFile.retrieveContent(any())).thenReturn('flutter:');
      when(() => mockPubspecLock.findIn(any())).thenReturn(null);
      when(
        () => mockScriptsYaml.executables(),
      ).thenReturn({'flutter': 'custom_flutter'});

      final tool = determineFlutterOrDart.tool();

      expect(tool, 'custom_flutter');
      expect(determineFlutterOrDart.isDart, isFalse);
      expect(determineFlutterOrDart.isFlutter, isTrue);
    });

    test('should return correct directory', () {
      final directory = determineFlutterOrDart.directory();

      expect(directory, 'path/to');
    });
  });
}

class _MockFindFile extends Mock implements FindFile {}

class _MockPubspecLock extends Mock implements PubspecLock {}

class _MockScriptsYaml extends Mock implements ScriptsYaml {}
