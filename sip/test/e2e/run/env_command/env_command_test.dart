import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/filter_type.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../../utils/test_scoped.dart';

void main() {
  group('env command e2e', () {
    late FileSystem fs;
    late _TestBindings bindings;

    setUp(() {
      bindings = _TestBindings();

      fs = MemoryFileSystem.test();

      final cwd = fs.directory(path.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

    @isTest
    void test(String description, void Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
      );
    }

    group('runs gracefully', () {
      late ScriptRunCommand command;

      ScriptRunCommand prep() {
        final input = io.File(
          path.join(
            'test',
            'e2e',
            'run',
            'env_command',
            'inputs',
            'scripts.yaml',
          ),
        ).readAsStringSync();

        fs.file(ScriptsYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync(input);
        fs.file(PubspecYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync('');

        final command = ScriptRunCommand();

        return command;
      }

      setUp(() {
        command = prep();
      });

      test('command: server pocketbase migrate', () async {
        await command.run(['server', 'pocketbase', 'migrate']);

        await Future<void>.delayed(Duration.zero);

        expect(bindings.scripts.join('\n'), r'''
cd /packages/sip || exit 1

cd infra || exit 1
dart run pnv generate env --flavor local --output private --directory public

cd /packages/sip || exit 1

if [ -f infra/private/pocketbase.local.env ]; then
  builtin source infra/private/pocketbase.local.env
  while IFS='=' read -r key _; do
    if [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "$key"
    fi
  done < <(grep -vE '^\s*#' infra/private/pocketbase.local.env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=')
else
  echo "ENV File infra/private/pocketbase.local.env not found"
  exit 1
fi

cd backend/pocketbase || exit 1
MIGRATIONS_COUNT=$(ls -1 pb_migrations | wc -l)
if [ "$MIGRATIONS_COUNT" -eq 0 ]; then
  echo "No migrations to apply"
  exit 0
fi

echo "y" | ./pocketbase migrate down $MIGRATIONS_COUNT

cd /packages/sip || exit 1

if [ -f infra/private/pocketbase.local.env ]; then
  builtin source infra/private/pocketbase.local.env
  while IFS='=' read -r key _; do
    if [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "$key"
    fi
  done < <(grep -vE '^\s*#' infra/private/pocketbase.local.env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=')
else
  echo "ENV File infra/private/pocketbase.local.env not found"
  exit 1
fi

cd backend/pocketbase &&./pocketbase migrate up
''');
      });
    });
  });
}

class _TestBindings implements Bindings {
  final List<String> scripts = [];

  @override
  Future<CommandResult> runScript(
    String script, {
    bool showOutput = false,
    FilterType? filterType,
    bool bail = false,
  }) async {
    scripts.addAll(script.split('\n'));

    return const CommandResult(exitCode: 0, output: '', error: '');
  }
}
