import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group(ScriptRunCommand, () {
    late FileSystem fileSystem;

    FileSystem createFs() {
      fileSystem = MemoryFileSystem.test();
      fileSystem.file('/scripts.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('hello: echo hi\n');

      return fileSystem;
    }

    // `--print` resolves the script and prints it without running anything,
    // so these assert resolution without touching a process.
    testScoped(
      'resolves a script named after the command path',
      fileSystem: createFs,
      args: () => Args.parse(['run', 'hello', '--print']),
      () async {
        expect(await const ScriptRunCommand().run(['hello']), ExitCode.success);
      },
    );

    testScoped(
      'resolves a script that follows a flag',
      fileSystem: createFs,
      args: () => Args.parse(['run', '--print', 'hello']),
      () async {
        // `Args` stops the command path at the first flag, so `run` receives
        // an empty path and the name is only reachable through `rest`.
        expect(await const ScriptRunCommand().run([]), ExitCode.success);
      },
    );

    testScoped(
      'lists the available scripts when none is named',
      fileSystem: createFs,
      args: () => Args.parse(['run', '--print']),
      () async {
        // With nothing in the path or in `rest` there is no name to fall back
        // to, so this stays the existing help-like listing rather than an
        // error.
        expect(await const ScriptRunCommand().run([]), ExitCode.success);
      },
    );
  });
}
