import 'package:sip_cli/src/domain/script_env.dart';
import 'package:test/test.dart';

void main() {
  group(ScriptEnv, () {
    group('#fromJson', () {
      group('should parse files', () {
        test('when files is a list', () {
          final env = ScriptEnv.fromJson(const {
            'files': ['file1', 'file2'],
          });

          expect(env.files, ['file1', 'file2']);
        });

        test('when files is a string', () {
          final env = ScriptEnv.fromJson(const {'files': 'file1'});

          expect(env.files, ['file1']);
        });

        test('when key is file', () {
          final env = ScriptEnv.fromJson(const {'file': 'file1'});

          expect(env.files, ['file1']);
        });
      });

      group('should parse commands', () {
        test('when commands is a list', () {
          final env = ScriptEnv.fromJson(const {
            'commands': ['command1', 'command2'],
          });

          expect(env.commands, ['command1', 'command2']);
        });

        test('when commands is a string', () {
          final env = ScriptEnv.fromJson(const {'commands': 'command1'});

          expect(env.commands, ['command1']);
        });

        test('when key is command', () {
          final env = ScriptEnv.fromJson(const {'command': 'command1'});

          expect(env.commands, ['command1']);
        });
      });

      group('should parse variables', () {
        test('when variables is a map', () {
          final env = ScriptEnv.fromJson(const {
            'variables': {'key1': 'value1', 'key2': 'value2'},
          });

          expect(env.vars, {'key1': 'value1', 'key2': 'value2'});
        });

        test('when key is vars', () {
          final env = ScriptEnv.fromJson(const {
            'vars': {'key1': 'value1', 'key2': 'value2'},
          });

          expect(env.vars, {'key1': 'value1', 'key2': 'value2'});
        });

        test('when values are dynamic', () {
          final env = ScriptEnv.fromJson(const {
            'vars': {
              'key1': 'value1',
              'key2': 1,
              'key3': 1.0,
              'key4': true,
              'key7': null,
              // -- ignored --
              'key5': ['hi'],
              'key6': {'hello': 'world'},
            },
          });

          expect(env.vars, {
            'key1': 'value1',
            'key2': '1',
            'key3': '1.0',
            'key4': 'true',
            'key7': '',
          });
        });
      });
    });
  });
}
