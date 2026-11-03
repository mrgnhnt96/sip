import 'dart:convert';

import 'package:file/memory.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/domain/test_reports.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group(TestReports, () {
    // What one `--file-reporter json:` run writes: ids count from 0 per run.
    String jsonRun(List<String> tests, {bool success = true}) {
      var id = 2;
      return [
        {'type': 'start', 'protocolVersion': '0.1.1', 'time': 0},
        {'type': 'allSuites', 'count': 1, 'time': 0},
        {
          'type': 'suite',
          'suite': {'id': 0, 'path': 'test/.test_optimizer_bucket_0.dart'},
          'time': 0,
        },
        {
          'type': 'group',
          'group': {'id': 1, 'suiteID': 0, 'parentID': null, 'name': null},
          'time': 0,
        },
        for (final name in tests) ...[
          {
            'type': 'group',
            'group': {
              'id': id,
              'suiteID': 0,
              'parentID': 1,
              'name': name.split(' ').first,
            },
            'time': 1,
          },
          {
            'type': 'testStart',
            'test': {
              'id': id + 1,
              'name': name,
              'suiteID': 0,
              'groupIDs': [1, id++],
            },
            'time': 1,
          },
          {'type': 'print', 'testID': id, 'message': 'hi', 'time': 2},
          {
            'type': 'testDone',
            'testID': id++,
            'result': name.contains('fails') ? 'failure' : 'success',
            'hidden': false,
            'skipped': false,
            'time': 3,
          },
        ],
        {'type': 'done', 'success': success, 'time': 4},
      ].map(jsonEncode).join('\n');
    }

    List<Map<String, Object?>> events(String content) => [
      for (final line in const LineSplitter().convert(content))
        jsonDecode(line) as Map<String, Object?>,
    ];

    group('nextArgument', () {
      testScoped(
        'passes nothing when the option is not set',
        fileSystem: MemoryFileSystem.test,
        () {
          expect(TestReports().nextArgument(null), isNull);
        },
      );

      testScoped(
        'gives every run a file of its own',
        fileSystem: MemoryFileSystem.test,
        () {
          final reports = TestReports();
          final files = <String>[];

          final arguments = [
            for (var i = 0; i < 2; i++)
              reports.nextArgument('json:results.json', reportFile: files.add),
          ];

          expect(files.toSet(), hasLength(2));
          expect(arguments, [
            for (final file in files) '--file-reporter json:$file',
          ]);
        },
      );

      testScoped(
        'passes a value without a reporter through for the runner to '
        'reject',
        fileSystem: MemoryFileSystem.test,
        () {
          expect(
            TestReports().nextArgument('results.json'),
            '--file-reporter results.json',
          );
        },
      );
    });

    group('write', () {
      testScoped(
        'merges every run into the given path, resolved against where sip '
        'was started, and removes the run files',
        fileSystem: MemoryFileSystem.test,
        () {
          fs.currentDirectory = fs.directory('/repo')..createSync();
          final reports = TestReports();
          final files = <String>[];
          reports
            ..nextArgument('expanded:out/log.txt', reportFile: files.add)
            ..nextArgument('expanded:out/log.txt', reportFile: files.add);
          fs.file(files[0]).writeAsStringSync('first\n');
          fs.file(files[1]).writeAsStringSync('second\n');

          reports.write();

          expect(
            fs.file('/repo/out/log.txt').readAsStringSync(),
            'first\nsecond\n',
          );
          expect(fs.file(files[0]).parent.existsSync(), isFalse);
        },
      );

      testScoped(
        'writes nothing when no run had a report',
        fileSystem: MemoryFileSystem.test,
        () {
          fs.currentDirectory = fs.directory('/repo')..createSync();

          TestReports().write();

          expect(fs.directory('/repo').listSync(), isEmpty);
        },
      );

      testScoped(
        'leaves out a discarded run whole',
        fileSystem: MemoryFileSystem.test,
        () {
          fs.currentDirectory = fs.directory('/repo')..createSync();
          final reports = TestReports();
          late String combined;
          late String fallback;
          reports
            ..nextArgument('json:r.json', reportFile: (f) => combined = f)
            ..nextArgument('json:r.json', reportFile: (f) => fallback = f)
            ..discardRun(combined);
          fs
              .file(combined)
              .writeAsStringSync(
                jsonRun(['loading test/.test_optimizer_bucket_0.dart']),
              );
          fs.file(fallback).writeAsStringSync(jsonRun(['a']));

          reports.write();

          final merged = events(fs.file('/repo/r.json').readAsStringSync());
          final names = [
            for (final e in merged)
              if (e case {'type': 'testStart', 'test': {'name': final n}}) n,
          ];

          expect(names, ['a']);
          expect(merged[1], containsPair('count', 1));
        },
      );

      testScoped(
        'leaves out the tests of discarded files',
        fileSystem: MemoryFileSystem.test,
        () {
          fs.currentDirectory = fs.directory('/repo')..createSync();
          final reports = TestReports();
          late String combined;
          late String fallback;
          reports
            ..nextArgument('json:r.json', reportFile: (f) => combined = f)
            ..nextArgument('json:r.json', reportFile: (f) => fallback = f)
            ..discard(combined, [r'test\b_test.dart']);
          fs
              .file(combined)
              .writeAsStringSync(
                jsonRun(['test/a_test.dart a', 'test/b_test.dart b']),
              );
          fs.file(fallback).writeAsStringSync(jsonRun(['b']));

          reports.write();

          final merged = events(fs.file('/repo/r.json').readAsStringSync());
          final names = [
            for (final e in merged)
              if (e case {'type': 'testStart', 'test': {'name': final n}}) n,
          ];

          expect(names, ['test/a_test.dart a', 'b']);
          expect(
            merged.where((e) => e['type'] == 'testDone'),
            hasLength(2),
            reason: "the discarded test's events go with it",
          );
        },
      );
    });

    group('mergeJson', () {
      ({String content, Set<String> discarded}) run(
        String content, [
        Set<String> discarded = const {},
      ]) => (content: content, discarded: discarded);

      test('keeps one start, sums the suites and ends with one done', () {
        final merged = events(
          TestReports.mergeJson([
            run(jsonRun(['test/a_test.dart a'])),
            run(jsonRun(['test/b_test.dart b'])),
          ]),
        );

        expect(merged.first['type'], 'start');
        expect(merged.where((e) => e['type'] == 'start'), hasLength(1));
        expect(merged[1], containsPair('count', 2));
        expect(merged.last, {'type': 'done', 'success': true, 'time': 4});
        expect(merged.where((e) => e['type'] == 'done'), hasLength(1));
      });

      test('moves each run past the ids of the run before it', () {
        final merged = events(
          TestReports.mergeJson([
            run(jsonRun(['test/a_test.dart a'])),
            run(jsonRun(['test/b_test.dart b'])),
          ]),
        );

        final suiteIds = [
          for (final e in merged)
            if (e case {'type': 'suite', 'suite': {'id': final id}}) id,
        ];
        final tests = [
          for (final e in merged)
            if (e case {
              'type': 'testStart',
              'test': final Map<String, Object?> t,
            })
              t,
        ];
        final doneIds = [
          for (final e in merged)
            if (e case {'type': 'testDone', 'testID': final id}) id,
        ];

        // Run 0 used ids 0-3, so run 1 starts at 4.
        expect(suiteIds, [0, 4]);
        expect(tests.map((t) => t['id']), [3, 7]);
        expect(tests.map((t) => t['suiteID']), [0, 4]);
        expect(tests.map((t) => t['groupIDs']), [
          [1, 2],
          [5, 6],
        ]);
        expect(doneIds, [3, 7]);
      });

      test('fails when a kept run failed', () {
        final merged = events(
          TestReports.mergeJson([
            run(jsonRun(['test/a_test.dart a'])),
            run(jsonRun(['test/b_test.dart b fails'], success: false)),
          ]),
        );

        expect(merged.last, containsPair('success', false));
      });

      test('passes when the only failure was discarded', () {
        final merged = events(
          TestReports.mergeJson([
            run(
              jsonRun([
                'test/a_test.dart a',
                'test/b_test.dart b fails',
              ], success: false),
              {'test/b_test.dart'},
            ),
            run(jsonRun(['b'])),
          ]),
        );

        expect(merged.last, containsPair('success', true));
      });

      test('skips a partial line left by a killed run', () {
        final merged = events(
          TestReports.mergeJson([
            run('${jsonRun(['test/a_test.dart a'])}\n{"type":"testSt'),
          ]),
        );

        expect(merged.where((e) => e['type'] == 'testStart'), hasLength(1));
      });
    });
  });
}
