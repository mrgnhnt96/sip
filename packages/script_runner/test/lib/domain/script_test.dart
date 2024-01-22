import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

void main() {
  group('$Script', () {
    group('#listOut', () {
      test('should list out the description', () {
        final script = Script.defaults(
          description: 'This is a description',
        );

        expect(
          script.listOut(),
          equals(
            '''(description): This is a description
''',
          ),
        );
      });

      test('should list out the aliases', () {
        final script = Script.defaults(
          aliases: {'alias1', 'alias2'},
        );

        expect(
          script.listOut(),
          equals(
            '''(aliases): alias1, alias2
''',
          ),
        );
      });

      test('should list out the scripts', () {
        final script = Script.defaults(
          scripts: ScriptsConfig(
            scripts: {
              'script1': Script.defaults(),
            },
          ),
        );

        expect(
          script.listOut(),
          startsWith('  + script1'),
        );
      });
    });
  });
}
