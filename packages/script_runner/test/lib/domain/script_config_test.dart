import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

void main() {
  group('$ScriptsConfig', () {
    group('#listOut', () {
      test('lists out the scripts', () {
        final scriptsConfig = ScriptsConfig(
          scripts: {
            'legend-of-zelda': Script.defaults(
              aliases: {'loz', 'legend', 'zelda'},
              description: 'The Legend of Zelda Games',
              commands: ['echo "Pick a game..."'],
              scripts: ScriptsConfig(
                scripts: {
                  'ocarina-of-time': Script.defaults(
                    description: 'Ocarina of Time',
                    aliases: {'oot'},
                    commands: ['echo "Now loading Ocarina of Time..."'],
                  ),
                  'majoras-mask': Script.defaults(
                    aliases: {'mm'},
                    description: "Majora's Mask",
                    commands: ['echo "Now loading Majora\'s Mask..."'],
                  ),
                },
              ),
            ),
            'mario': Script.defaults(
              aliases: {'super-mario', 'super-mario-bros'},
              description: 'The Super Mario Bros Games',
              commands: ['echo "Pick a game..."'],
              scripts: ScriptsConfig(
                scripts: {
                  'super-mario-bros': Script.defaults(
                    description: 'Super Mario Bros',
                    aliases: {'smb'},
                    commands: ['echo "Now loading Super Mario Bros..."'],
                  ),
                  'super-mario-world': Script.defaults(
                    description: 'Super Mario World',
                    aliases: {'smw'},
                    commands: ['echo "Now loading Super Mario World..."'],
                  ),
                },
              ),
            ),
          },
        );

        const expected = '''
scripts.yaml:
   ├──legend-of-zelda
   │  (description): The Legend of Zelda Games
   │  (aliases): loz, legend, zelda
   │    ├──ocarina-of-time
   │    │  (description): Ocarina of Time
   │    │  (aliases): oot
   │    └──majoras-mask
   │       (description): Majora's Mask
   │       (aliases): mm
   └──mario
      (description): The Super Mario Bros Games
      (aliases): super-mario, super-mario-bros
        ├──super-mario-bros
        │  (description): Super Mario Bros
        │  (aliases): smb
        └──super-mario-world
           (description): Super Mario World
           (aliases): smw
''';

        expect(
          scriptsConfig.listOut(),
          expected.trimLeft(),
        );
      });
    });
  });
}
