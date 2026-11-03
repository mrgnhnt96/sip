import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/find_file.dart';
import 'package:sip_cli/src/domain/message.dart';
import 'package:sip_cli/src/domain/message_action.dart';
import 'package:sip_cli/src/domain/pubspec_lock.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/package.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  const success = CommandResult(exitCode: 0, output: 'output', error: 'error');
  final failure = CommandResult(
    exitCode: ExitCode.config.code,
    output: 'output',
    error: 'error',
  );

  group(TesterMixin, () {
    late _Tester tester;
    late FileSystem fs;
    late Bindings bindings;
    late Logger logger;
    late FindFile findFile;
    late PubspecLock pubspecLock;
    late ScriptsYaml scriptsYaml;

    setUp(() {
      bindings = _MockBindings();
      logger = _MockLogger();
      findFile = _MockFindFile();
      pubspecLock = _MockPubspecLock();
      scriptsYaml = _MockScriptsYaml();

      fs = MemoryFileSystem.test();

      tester = const _Tester();

      // Set up default mocks for Package dependencies
      when(() => findFile.retrieveContent(any())).thenReturn(null);
      when(() => pubspecLock.findIn(any())).thenReturn(null);
      when(() => scriptsYaml.executables()).thenReturn(null);
    });

    @isTest
    void test(
      String description,
      FutureOr<void> Function() fn, {
      Object? skip,
      Args Function()? args,
    }) {
      testScoped(
        description,
        fn,
        args: args,
        fileSystem: () => fs,
        bindings: () => bindings,
        logger: () => logger,
        findFile: () => findFile,
        pubspecLock: () => pubspecLock,
        scriptsYaml: () => scriptsYaml,
        skip: skip,
      );
    }

    group('#packageRootFor', () {
      group('successfully returns the path when', () {
        test('a dir path is provided', () async {
          final expected = {
            'test': '.',
            'test/': '.',
            'test/sub': '.',
            'test/sub/': '.',
            'lib': '.',
            'lib/': '.',
            'lib/src': '.',
            'lib/src/': '.',
          };

          for (final entry in expected.entries) {
            final result = tester.packageRootFor(entry.key);
            expect(result, entry.value);
          }
        });

        test('a file path is provided', () {
          final expected = {
            'test/some_test.dart': '.',
            'test/sub/some_test.dart': '.',
            'lib/some_file.dart': '.',
            'lib/src/some_file.dart': '.',
          };

          for (final entry in expected.entries) {
            final result = tester.packageRootFor(entry.key);
            expect(result, entry.value);
          }
        });

        test('when nested in a sub package', () {
          final expected = {
            'packages/ui/test': 'packages/ui',
            'packages/ui/lib': 'packages/ui',
            'packages/ui/lib/some_file.dart': 'packages/ui',
            'packages/ui/test/some_file.dart': 'packages/ui',
          };

          for (final entry in expected.entries) {
            final result = tester.packageRootFor(entry.key);
            expect(result, entry.value);
          }
        });
      });
    });

    group('#runCommands', () {
      test('should run commands', () async {
        when(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).thenAnswer((_) => Future.value(success));

        final commands = [ScriptToRun('something', workingDirectory: '.')];

        final results = await tester.runCommands(
          commands,
          bail: false,
          showOutput: false,
        );

        expect(results, ExitCode.success);
      });

      test('should bail when first fails', () async {
        when(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).thenAnswer((_) => Future.value(failure));

        final commands = [
          ScriptToRun('something', workingDirectory: '.'),
          ScriptToRun('else', workingDirectory: '.'),
        ];

        final results = await tester.runCommands(
          commands,
          bail: true,
          showOutput: false,
        );

        expect(results, ExitCode.software);
        // The second command must never be launched.
        verify(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).called(1);
      });

      test('should fail when a command exits non-zero', () async {
        // The output parser is the only source of pass/fail, so a failure it
        // does not recognize used to be reported as a pass: `dart test` exits
        // 1 while sip printed `Results: ✅ n ❌ 0` and exited 0.
        when(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).thenAnswer((_) => Future.value(failure));

        final result = await tester.runCommands(
          [ScriptToRun('something', workingDirectory: '.')],
          bail: false,
          showOutput: false,
        );

        expect(result, ExitCode.software);
      });

      test('should succeed when every command exits zero', () async {
        when(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).thenAnswer((_) => Future.value(success));

        final result = await tester.runCommands(
          [
            ScriptToRun('something', workingDirectory: '.'),
            ScriptToRun('else', workingDirectory: '.'),
          ],
          bail: false,
          showOutput: false,
        );

        expect(result, ExitCode.success);
      });

      group('should run all commands', () {
        test('concurrently', () async {
          when(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).thenAnswer((_) => Future.value(success));

          final commands = [
            ScriptToRun('something', workingDirectory: '.'),
            ScriptToRun('else', workingDirectory: '.'),
          ];

          final results = await tester.runCommands(
            commands,
            bail: false,
            showOutput: true,
          );

          expect(results, ExitCode.success);
          verify(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).called(2);
        });

        test('not concurrently', () async {
          when(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).thenAnswer((_) => Future.value(success));

          final commands = [
            ScriptToRun('something', workingDirectory: '.'),
            ScriptToRun('else', workingDirectory: '.'),
          ];

          final results = await tester.runCommands(
            commands,
            bail: false,
            showOutput: false,
          );

          expect(results, ExitCode.success);
          verify(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).called(2);
        });
      });
    });

    group('#runCommands runs that never started', () {
      // Concurrent `flutter test` runs in one package race on its build
      // directory: the loser exits 1 before running a single test, and its
      // tests used to vanish from the count.
      const race = CommandResult(exitCode: 1, output: '', error: '');

      late Map<String, int> calls;

      void mockRuns(
        CommandResult Function(
          String script,
          int call,
          MessageAction? Function(Message) onOutput,
        )
        answer,
      ) {
        calls = {};
        when(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).thenAnswer((invocation) async {
          final command = invocation.positionalArguments.first as String;
          final script = RegExp(r'run_slice_(\w)').firstMatch(command)![1]!;
          final onOutput =
              invocation.namedArguments[#onOutput]
                  as MessageAction? Function(Message);
          final call = calls[script] = (calls[script] ?? 0) + 1;

          return answer(script, call, onOutput);
        });
      }

      CommandResult passes(
        MessageAction? Function(Message) onOutput,
        String t,
      ) {
        onOutput(Message('✅ test/${t}_test.dart $t passes'));
        return success;
      }

      List<ScriptToRun> slices({String Function(String)? directory}) => [
        for (final name in ['a', 'b', 'c'])
          ScriptToRun(
            'run_slice_$name',
            workingDirectory: directory?.call(name) ?? '/project',
            label: 'slice $name',
            runInParallel: true,
          ),
      ];

      test('re-runs on its own a run that exited non-zero before reporting '
          'a test while other runs shared its directory', () async {
        mockRuns((script, call, onOutput) {
          if (script == 'c' && call == 1) return race;
          return passes(onOutput, script);
        });

        final exitCode = await tester.runCommands(
          slices(),
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.success);
        expect(calls, {'a': 1, 'b': 1, 'c': 2});
        verify(
          () => logger.warn(
            any(
              that: allOf(
                contains('slice c exited with code 1'),
                contains('re-running it on its own'),
              ),
            ),
          ),
        ).called(1);
      });

      test('re-runs a run whose only output was not a test result', () async {
        mockRuns((script, call, onOutput) {
          if (script == 'c' && call == 1) {
            onOutput(
              const Message(
                'Waiting for another flutter command to release the '
                'startup lock...',
              ),
            );
            return race;
          }
          return passes(onOutput, script);
        });

        final exitCode = await tester.runCommands(
          slices(),
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.success);
        expect(calls, {'a': 1, 'b': 1, 'c': 2});
      });

      test('counts the re-run in the results', () async {
        mockRuns((script, call, onOutput) {
          if (script == 'c' && call == 1) return race;
          return passes(onOutput, script);
        });

        await tester.runCommands(
          slices(),
          bail: false,
          showOutput: false,
          asJson: true,
        );

        final written = verify(
          () => logger.write(captureAny()),
        ).captured.cast<String>().join();
        final json =
            jsonDecode(written.substring(written.indexOf('{')))
                as Map<String, Object?>;
        expect(json['counts'], containsPair('passing', 3));
        expect(json['passed'], isTrue);
      });

      test('fails when the re-run fails too', () async {
        mockRuns((script, call, onOutput) {
          if (script == 'c') return race;
          return passes(onOutput, script);
        });

        final exitCode = await tester.runCommands(
          slices(),
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.software);
        expect(calls, {'a': 1, 'b': 1, 'c': 2});
      });

      test('does not re-run a run alone in its directory', () async {
        mockRuns((script, call, onOutput) {
          if (script == 'c') return race;
          return passes(onOutput, script);
        });

        final exitCode = await tester.runCommands(
          slices(directory: (name) => '/project/$name'),
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.software);
        expect(calls, {'a': 1, 'b': 1, 'c': 1});
      });

      test('does not re-run a run that reported a test', () async {
        mockRuns((script, call, onOutput) {
          if (script == 'c') {
            passes(onOutput, script);
            return race;
          }
          return passes(onOutput, script);
        });

        final exitCode = await tester.runCommands(
          slices(),
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.software);
        expect(calls, {'a': 1, 'b': 1, 'c': 1});
      });

      test('does not re-run once a test failed with bail set', () async {
        mockRuns((script, call, onOutput) {
          if (script == 'a') {
            onOutput(const Message('❌ test/a_test.dart a fails (failed)'));
            return failure;
          }
          if (script == 'c') return race;
          return passes(onOutput, script);
        });

        final exitCode = await tester.runCommands(
          slices(),
          bail: true,
          showOutput: false,
        );

        expect(exitCode, ExitCode.software);
        expect(calls['c'], 1);
      });

      test('does not re-run once the compiler crashed', () async {
        mockRuns((script, call, onOutput) {
          if (script == 'a') {
            onOutput(const Message('The Dart compiler exited unexpectedly'));
            return failure;
          }
          if (script == 'c') return race;
          return passes(onOutput, script);
        });

        final exitCode = await tester.runCommands(
          slices(),
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.software);
        expect(calls['c'], 1);
      });
    });

    group('#runCommands experimental bucket fallback', () {
      Package bucketPackage() {
        fs.file('/project/pubspec.yaml')
          ..createSync(recursive: true)
          ..writeAsStringSync('name: project');

        return Package('/project/pubspec.yaml');
      }

      void mockRunScriptWithOutput(
        Future<CommandResult> Function(
          String script,
          MessageAction? Function(Message) onOutput,
        )
        answer,
      ) {
        when(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).thenAnswer((invocation) {
          final script = invocation.positionalArguments.first as String;
          final onOutput =
              invocation.namedArguments[#onOutput]
                  as MessageAction? Function(Message);

          return answer(script, onOutput);
        });
      }

      test("discards a bucket's results and re-runs its files individually "
          'when one of them never reports a result', () async {
        mockRunScriptWithOutput((script, onOutput) async {
          if (script.contains('.test_optimizer_bucket_0.dart')) {
            // Simulates a compile error/hard assertion cutting the bucket
            // short after only the first file's tests ran. Multi-file
            // invocations prefix with the physical wrapper file and push
            // the original file's group name into the `test` field (see
            // TesterMixin._bucketFileWasReported).
            onOutput(
              const Message(
                '✅ test/.test_optimizer_bucket_0.dart: '
                'test/a_test.dart a passes',
              ),
            );
            return const CommandResult(exitCode: 1, output: '', error: '');
          }

          onOutput(const Message('✅ test/a_test.dart a passes'));
          onOutput(const Message('✅ test/b_test.dart b passes'));
          return success;
        });

        final pkg = bucketPackage();
        final bucketCommand = tester.createTestCommand(
          pkg: pkg,
          tests: ['test/.test_optimizer_bucket_0.dart'],
          bail: false,
          bucketFileGroups: [
            ['test/a_test.dart', 'test/b_test.dart'],
          ],
        );

        final exitCode = await tester.runCommands(
          [bucketCommand],
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.success);
        verify(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).called(2);
        verify(
          () => logger.warn(
            any(
              that: allOf(
                contains('failed when combined'),
                contains('re-running 2 file(s) individually'),
              ),
            ),
          ),
        ).called(1);
      });

      test(
        'only discards and re-runs the compromised group, leaving a '
        "healthy group sharing the same invocation's results untouched",
        () async {
          // One shard-level invocation covering TWO combined buckets:
          // bucket 0 (a_test/b_test) fails to fully report; bucket 1
          // (c_test) reports cleanly and should be left alone.
          mockRunScriptWithOutput((script, onOutput) async {
            if (script.contains('.test_optimizer_bucket_0.dart') &&
                script.contains('.test_optimizer_bucket_1.dart')) {
              onOutput(
                const Message(
                  '✅ test/.test_optimizer_bucket_0.dart: '
                  'test/a_test.dart a passes',
                ),
              );
              onOutput(
                const Message(
                  '✅ test/.test_optimizer_bucket_1.dart: '
                  'test/c_test.dart c passes',
                ),
              );
              return const CommandResult(exitCode: 1, output: '', error: '');
            }

            onOutput(const Message('✅ test/a_test.dart a passes'));
            onOutput(const Message('✅ test/b_test.dart b passes'));
            return success;
          });

          final pkg = bucketPackage();
          final shardCommand = tester.createTestCommand(
            pkg: pkg,
            tests: [
              'test/.test_optimizer_bucket_0.dart',
              'test/.test_optimizer_bucket_1.dart',
            ],
            bail: false,
            bucketFileGroups: [
              ['test/a_test.dart', 'test/b_test.dart'],
              ['test/c_test.dart'],
            ],
          );

          final exitCode = await tester.runCommands(
            [shardCommand],
            bail: false,
            showOutput: false,
          );

          expect(exitCode, ExitCode.success);
          // One call for the shard invocation, one fallback call containing
          // only bucket 0's files -- bucket 1's already-healthy result for
          // c_test is kept, not redundantly re-run.
          final calls = verify(
            () => bindings.runScriptWithOutput(
              captureAny(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          )..called(2);
          final fallbackScript = calls.captured.last as String;
          expect(fallbackScript, contains('test/a_test.dart'));
          expect(fallbackScript, contains('test/b_test.dart'));
          expect(fallbackScript, isNot(contains('test/c_test.dart')));
          verify(
            () => logger.warn(
              any(
                that: allOf(
                  contains('failed when combined'),
                  contains('1/2 combined group(s)'),
                  contains('re-running 2 file(s) individually'),
                ),
              ),
            ),
          ).called(1);
        },
      );

      test('does not fall back when a file in the bucket is skipped by tag '
          '(#29)', () async {
        // What `flutter test` printed for a bucket holding a file whose
        // tag is configured `skip:` in dart_test.yaml: its test is reported
        // in a trailing "Skipped tests" section, after the passes.
        mockRunScriptWithOutput((script, onOutput) async {
          onOutput(
            const Message(
              '::group::✅ Passing tests\n'
              '✅ test/a_test.dart a\n',
            ),
          );
          onOutput(const Message('::endgroup::\n::group::⏭️ Skipped tests\n'));
          onOutput(const Message('⏭️ test/tagged_test.dart tagged (skipped)'));
          onOutput(const Message('Skip: run with --tags internal-build'));
          onOutput(const Message('::endgroup::\n🎉 1 test passed, 1 skipped.'));
          return success;
        });

        final pkg = bucketPackage();
        final bucketCommand = tester.createTestCommand(
          pkg: pkg,
          tests: ['test/.test_optimizer_bucket_0.dart'],
          bail: false,
          bucketFileGroups: [
            ['test/a_test.dart', 'test/tagged_test.dart'],
          ],
        );

        final exitCode = await tester.runCommands(
          [bucketCommand],
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.success);
        verify(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).called(1);
        verifyNever(() => logger.warn(any(that: contains('re-running'))));
      });

      test(
        'merges --file-reporter into one report, leaving out what a '
        'fallback re-ran',
        args: () => const Args(args: {'file-reporter': 'json:report.json'}),
        () async {
          fs.currentDirectory = fs.directory('/project')
            ..createSync(recursive: true);

          // Each simulated run writes the report a real one would, to the
          // file sip passed it.
          void writeReport(String script, List<String> tests) {
            final path = RegExp(
              r'--file-reporter json:(\S+)',
            ).firstMatch(script)!.group(1)!;
            var id = 1;
            fs
                .file(path)
                .writeAsStringSync(
                  [
                    {'type': 'start', 'time': 0},
                    {'type': 'allSuites', 'count': 1, 'time': 0},
                    {
                      'type': 'suite',
                      'suite': {'id': 0},
                      'time': 0,
                    },
                    for (final name in tests) ...[
                      {
                        'type': 'testStart',
                        'test': {'id': id, 'name': name, 'suiteID': 0},
                        'time': 1,
                      },
                      {
                        'type': 'testDone',
                        'testID': id++,
                        'result': 'success',
                        'time': 2,
                      },
                    ],
                    {'type': 'done', 'success': true, 'time': 3},
                  ].map(jsonEncode).join('\n'),
                );
          }

          mockRunScriptWithOutput((script, onOutput) async {
            if (script.contains('.test_optimizer_bucket_0.dart')) {
              // Bucket 0 is cut short after a_test; bucket 1 is healthy.
              writeReport(script, [
                'test/a_test.dart a passes',
                'test/c_test.dart c passes',
              ]);
              onOutput(
                const Message(
                  '✅ test/.test_optimizer_bucket_0.dart: '
                  'test/a_test.dart a passes',
                ),
              );
              onOutput(
                const Message(
                  '✅ test/.test_optimizer_bucket_1.dart: '
                  'test/c_test.dart c passes',
                ),
              );
              return const CommandResult(exitCode: 1, output: '', error: '');
            }

            writeReport(script, ['a passes', 'b passes']);
            onOutput(const Message('✅ test/a_test.dart a passes'));
            onOutput(const Message('✅ test/b_test.dart b passes'));
            return success;
          });

          final pkg = bucketPackage();
          final shardCommand = tester.createTestCommand(
            pkg: pkg,
            tests: [
              'test/.test_optimizer_bucket_0.dart',
              'test/.test_optimizer_bucket_1.dart',
            ],
            bail: false,
            bucketFileGroups: [
              ['test/a_test.dart', 'test/b_test.dart'],
              ['test/c_test.dart'],
            ],
          );

          final exitCode = await tester.runCommands(
            [shardCommand],
            bail: false,
            showOutput: false,
          );

          expect(exitCode, ExitCode.success);

          final report = fs.file('/project/report.json');
          expect(report.existsSync(), isTrue);
          final events = [
            for (final line in report.readAsLinesSync())
              jsonDecode(line) as Map<String, Object?>,
          ];
          final names = [
            for (final e in events)
              if (e case {'type': 'testStart', 'test': {'name': final n}}) n,
          ];

          expect(names, ['test/c_test.dart c passes', 'a passes', 'b passes']);
          expect(events.last, containsPair('success', true));
        },
      );

      test('does not fall back when the bucket runs cleanly', () async {
        mockRunScriptWithOutput((script, onOutput) async {
          onOutput(
            const Message(
              '✅ test/.test_optimizer_bucket_0.dart: test/a_test.dart a passes',
            ),
          );
          onOutput(
            const Message(
              '✅ test/.test_optimizer_bucket_0.dart: test/b_test.dart b passes',
            ),
          );
          return success;
        });

        final pkg = bucketPackage();
        final bucketCommand = tester.createTestCommand(
          pkg: pkg,
          tests: ['test/.test_optimizer_bucket_0.dart'],
          bail: false,
          bucketFileGroups: [
            ['test/a_test.dart', 'test/b_test.dart'],
          ],
        );

        final exitCode = await tester.runCommands(
          [bucketCommand],
          bail: false,
          showOutput: false,
        );

        expect(exitCode, ExitCode.success);
        verify(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).called(1);
        verifyNever(() => logger.warn(any(that: contains('re-running'))));
      });

      test(
        'does not fall back for a genuine failure that still fully reports',
        () async {
          mockRunScriptWithOutput((script, onOutput) async {
            onOutput(
              const Message(
                '✅ test/.test_optimizer_bucket_0.dart: '
                'test/a_test.dart a passes',
              ),
            );
            onOutput(
              const Message(
                '❌ test/.test_optimizer_bucket_0.dart: '
                'test/b_test.dart b fails (failed)',
              ),
            );
            return failure;
          });

          final pkg = bucketPackage();
          final bucketCommand = tester.createTestCommand(
            pkg: pkg,
            tests: ['test/.test_optimizer_bucket_0.dart'],
            bail: false,
            bucketFileGroups: [
              ['test/a_test.dart', 'test/b_test.dart'],
            ],
          );

          final exitCode = await tester.runCommands(
            [bucketCommand],
            bail: false,
            showOutput: false,
          );

          expect(exitCode, ExitCode.software);
          verify(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).called(1);
          verifyNever(() => logger.warn(any(that: contains('re-running'))));
        },
      );

      group('with retryBucketFailures', () {
        const bucket = 'test/.test_optimizer_bucket_0.dart';

        // b_test fails inside the combined bucket; [passesAlone] decides how
        // it does when re-run on its own.
        void mockCombinedFailure({required bool passesAlone}) {
          mockRunScriptWithOutput((script, onOutput) async {
            if (script.contains(bucket)) {
              onOutput(const Message('✅ $bucket: test/a_test.dart a passes'));
              onOutput(
                const Message('❌ $bucket: test/b_test.dart b fails (failed)'),
              );
              return failure;
            }

            if (passesAlone) {
              onOutput(const Message('✅ test/b_test.dart b fails'));
              return success;
            }

            onOutput(const Message('❌ test/b_test.dart b fails (failed)'));
            return failure;
          });
        }

        Future<(ExitCode, Map<String, Object?>)> runAsJson(
          List<List<String>> bucketFileGroups,
        ) async {
          final command = tester.createTestCommand(
            pkg: bucketPackage(),
            tests: [bucket],
            bail: false,
            bucketFileGroups: bucketFileGroups,
          );

          final exitCode = await tester.runCommands(
            [command],
            bail: false,
            showOutput: false,
            asJson: true,
            retryBucketFailures: true,
          );

          final written = verify(
            () => logger.write(captureAny()),
          ).captured.cast<String>();
          final json = jsonDecode(written.last) as Map<String, Object?>;

          return (exitCode, json);
        }

        List<String> scriptsRun() {
          return verify(
            () => bindings.runScriptWithOutput(
              captureAny(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).captured.cast<String>();
        }

        test('reports a file that passes alone as failing only when '
            'combined, and still fails the run', () async {
          mockCombinedFailure(passesAlone: true);

          final (exitCode, json) = await runAsJson([
            ['test/a_test.dart', 'test/b_test.dart'],
          ]);

          expect(exitCode, ExitCode.software);
          expect(json['combinedOnlyFailures'], [
            {
              'path': 'test/b_test.dart',
              'tests': ['b fails'],
            },
          ]);
          expect(json['passed'], isFalse);
          expect(json['counts'], {'passing': 1, 'failing': 1, 'skipped': 0});

          final scripts = scriptsRun();
          expect(scripts, hasLength(2));
          expect(scripts.last, contains('test/b_test.dart'));
          expect(scripts.last, isNot(contains(bucket)));
        });

        test('keeps a file that also fails alone a plain failure', () async {
          mockCombinedFailure(passesAlone: false);

          final (exitCode, json) = await runAsJson([
            ['test/a_test.dart', 'test/b_test.dart'],
          ]);

          expect(exitCode, ExitCode.software);
          expect(json['combinedOnlyFailures'], isEmpty);
          expect(json['counts'], {'passing': 1, 'failing': 1, 'skipped': 0});
          expect(scriptsRun(), hasLength(2));
        });

        test('does not re-run a file that already ran alone', () async {
          mockCombinedFailure(passesAlone: true);

          final (exitCode, json) = await runAsJson([
            ['test/a_test.dart'],
            ['test/b_test.dart'],
          ]);

          expect(exitCode, ExitCode.software);
          expect(json['combinedOnlyFailures'], isEmpty);
          expect(scriptsRun(), hasLength(1));
        });

        test('does not re-run anything when the flag is off', () async {
          mockCombinedFailure(passesAlone: true);

          final command = tester.createTestCommand(
            pkg: bucketPackage(),
            tests: [bucket],
            bail: false,
            bucketFileGroups: [
              ['test/a_test.dart', 'test/b_test.dart'],
            ],
          );

          final exitCode = await tester.runCommands(
            [command],
            bail: false,
            showOutput: false,
          );

          expect(exitCode, ExitCode.software);
          expect(scriptsRun(), hasLength(1));
        });

        test('warns about combined-only failures in pretty output', () async {
          mockCombinedFailure(passesAlone: true);

          final command = tester.createTestCommand(
            pkg: bucketPackage(),
            tests: [bucket],
            bail: false,
            bucketFileGroups: [
              ['test/a_test.dart', 'test/b_test.dart'],
            ],
          );

          final exitCode = await tester.runCommands(
            [command],
            bail: false,
            showOutput: false,
            retryBucketFailures: true,
          );

          expect(exitCode, ExitCode.software);
          verify(
            () => logger.warn(
              any(
                that: allOf(
                  contains('1 file(s) fail only when combined'),
                  contains('test/b_test.dart'),
                  contains('- b fails'),
                ),
              ),
            ),
          ).called(1);
        });
      });
    });

    group('#cleanUp', () {
      test('should delete optimized files', () {
        const path = 'test/${TesterMixin.optimizedTestBasename}';
        fs.file(path).createSync(recursive: true);

        tester.cleanUpOptimizedFiles([path]);

        expect(fs.file(path).existsSync(), isFalse);
      });

      test('should not delete non optimized file', () {
        fs.file('test/other.dart').createSync(recursive: true);

        tester.cleanUpOptimizedFiles(['test/other.dart']);

        expect(fs.file('test/other.dart').existsSync(), isTrue);
      });
    });

    group('#createTestCommand', () {
      test(
        'forwards --file-reporter, each run to a file of its own',
        args: () => const Args(args: {'file-reporter': 'json:results.json'}),
        () {
          fs.currentDirectory = fs.directory('/project')
            ..createSync(recursive: true);
          fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
          final pkg = Package('/project/pubspec.yaml');

          ScriptToRun command({bool writeReport = true}) =>
              tester.createTestCommand(
                    pkg: pkg,
                    tests: [],
                    bail: false,
                    writeReport: writeReport,
                  )
                  as ScriptToRun;

          final first = command();
          final second = command();

          expect(first.reportFile, isNotNull);
          expect(
            first.exe,
            contains('--file-reporter json:${first.reportFile}'),
          );
          expect(second.reportFile, isNot(first.reportFile));
          expect(
            command(writeReport: false).exe,
            isNot(contains('--file-reporter')),
          );
        },
      );

      test('should show root directory when no tests provided and at root', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: [],
          bail: false,
        );

        // Extract path from label (format: "Running (dart) tests in <path>")
        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in .'));
      });

      test('should show provided test file path', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs.file('/project/test/some_test.dart').createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/some_test.dart'],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in test'));
      });

      test('should show provided test directory path', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs.directory('/project/test/subdir').createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/subdir'],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in test/subdir'));
      });

      test('should show relative path when in subdirectory', () {
        // Set up nested package
        fs.currentDirectory = fs.directory('/workspace')
          ..createSync(recursive: true);
        fs.directory('/workspace/packages/my_pkg').createSync(recursive: true);
        fs.file('/workspace/packages/my_pkg/pubspec.yaml').createSync();
        fs
            .file('/workspace/packages/my_pkg/pubspec.yaml')
            .writeAsStringSync('name: my_pkg');
        fs
            .file('/workspace/packages/my_pkg/test/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/workspace/packages/my_pkg/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/workspace/packages/my_pkg/test/some_test.dart'],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in packages/my_pkg/test'));
      });

      test('should show root when no tests provided in nested package', () {
        // Set up nested package
        fs.currentDirectory = fs.directory('/workspace')
          ..createSync(recursive: true);
        fs.directory('/workspace/packages/my_pkg').createSync(recursive: true);
        fs.file('/workspace/packages/my_pkg/pubspec.yaml').createSync();
        fs
            .file('/workspace/packages/my_pkg/pubspec.yaml')
            .writeAsStringSync('name: my_pkg');

        final pkg = Package('/workspace/packages/my_pkg/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: [],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        // Should show the package's relative path from current directory
        expect(label, contains('tests in packages/my_pkg'));
      });

      test('should handle relative test paths', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs
            .file('/project/test/subdir/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        // Pass relative path (relative to package path)
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['test/subdir/some_test.dart'],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in test/subdir'));
      });

      test('should show provided directory, not subdirectories '
          'where test files were found', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        // Create test file in a subdirectory
        fs
            .file('/project/test/lib/screens/home_profile/edit/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        // When a directory is provided, show that directory,
        // not the subdirectory
        // where test files were found
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: [
            '/project/test/lib/screens/home_profile/edit',
          ], // resolved test dir
          bail: false,
          providedPaths: [
            'test/lib/screens/home_profile',
          ], // original provided path
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        // Should show the provided directory, not the subdirectory
        expect(label, contains('tests in test/lib/screens/home_profile'));
        expect(label, isNot(contains('edit')));
      });

      test('should show "." when "." is provided', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs
            .file('/project/test/utils/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        // When "." is provided, show "." not the resolved test directories
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/utils'], // resolved test dir
          bail: false,
          providedPaths: ['.'], // original provided path
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        // Should show "." not "test/utils"
        expect(label, contains('tests in .'));
        expect(label, isNot(contains('test/utils')));
      });

      test(
        'should show "." when no paths are provided (sip test with no args)',
        () {
          // Set up root directory with pubspec.yaml
          fs.currentDirectory = fs.directory('/project')
            ..createSync(recursive: true);
          fs.file('/project/pubspec.yaml').createSync();
          fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
          fs
              .file('/project/test/utils/some_test.dart')
              .createSync(recursive: true);

          final pkg = Package('/project/pubspec.yaml');
          // When no paths are provided, show "." not the
          // resolved test directories
          final command = tester.createTestCommand(
            pkg: pkg,
            tests: ['/project/test/utils'], // resolved test dir from package
            bail: false,
            providedPaths: [], // empty list means no paths were provided
          );

          final scriptToRun = command as ScriptToRun;
          final label = scriptToRun.label;
          // Should show "." not "test/utils"
          expect(label, contains('tests in .'));
          expect(label, isNot(contains('test/utils')));
        },
      );

      test('should not include test paths in command when "." is provided', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs
            .file('/project/test/utils/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/utils'], // resolved test dir
          bail: false,
          providedPaths: ['.'], // original provided path
        );

        final scriptToRun = command as ScriptToRun;
        final script = scriptToRun.exe;
        // Should not include test paths, just run "dart test" or "flutter test"
        expect(script, isNot(contains('test/utils')));
        expect(script, contains('test'));
      });

      test(
        'should not include test paths in command when "test" is provided',
        () {
          // Set up root directory with pubspec.yaml
          fs.currentDirectory = fs.directory('/project')
            ..createSync(recursive: true);
          fs.file('/project/pubspec.yaml').createSync();
          fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
          fs
              .file('/project/test/utils/some_test.dart')
              .createSync(recursive: true);

          final pkg = Package('/project/pubspec.yaml');
          final command = tester.createTestCommand(
            pkg: pkg,
            tests: ['/project/test/utils'], // resolved test dir
            bail: false,
            providedPaths: ['test'], // original provided path
          );

          final scriptToRun = command as ScriptToRun;
          final script = scriptToRun.exe;
          // Should not include test paths, just run "dart test"
          // or "flutter test"
          expect(script, isNot(contains('test/utils')));
          expect(script, contains('test'));
        },
      );

      test('should not include test paths in command when '
          'no paths provided', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs
            .file('/project/test/utils/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/utils'], // resolved test dir
          bail: false,
          providedPaths: [], // no paths provided
        );

        final scriptToRun = command as ScriptToRun;
        final script = scriptToRun.exe;
        // Should not include test paths, just run "dart test" or "flutter test"
        expect(script, isNot(contains('test/utils')));
        expect(script, contains('test'));
      });

      test(
        'should include test paths in command when specific path is provided',
        () {
          // Set up root directory with pubspec.yaml
          fs.currentDirectory = fs.directory('/project')
            ..createSync(recursive: true);
          fs.file('/project/pubspec.yaml').createSync();
          fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
          fs
              .file('/project/test/utils/some_test.dart')
              .createSync(recursive: true);

          final pkg = Package('/project/pubspec.yaml');
          final command = tester.createTestCommand(
            pkg: pkg,
            tests: ['/project/test/utils'], // resolved test dir
            bail: false,
            providedPaths: ['test/utils'], // specific path provided
          );

          final scriptToRun = command as ScriptToRun;
          final script = scriptToRun.exe;
          // Should include the test path
          expect(script, contains('test/utils'));
        },
      );
    });
  });
}

class _Tester extends TesterMixin {
  const _Tester();
}

class _MockBindings extends Mock implements Bindings {}

class _MockLogger extends Mock implements Logger {
  @override
  Progress progress(String message, {ProgressOptions? options}) {
    return _MockProgress();
  }

  @override
  Level get level => Level.quiet;
}

class _MockProgress extends Mock implements Progress {}

class _MockFindFile extends Mock implements FindFile {}

class _MockPubspecLock extends Mock implements PubspecLock {}

class _MockScriptsYaml extends Mock implements ScriptsYaml {}
