import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:sip_cli/commands/update_command.dart';
import 'package:test/test.dart';

class _MockPubUpdater extends Mock implements PubUpdater {}

class _MockLogger extends Mock implements Logger {}

void main() {
  group(UpdateCommand, () {
    late UpdateCommand updateCommand;

    setUp(() {
      updateCommand = UpdateCommand(
        pubUpdater: _MockPubUpdater(),
        logger: _MockLogger(),
      );
    });

    group('#isLocalVersion', () {
      test('should return false if the versions match', () {
        final result = updateCommand.isLocalVersion(
          current: '0.0.0',
          latest: '0.0.0',
        );

        expect(result, isFalse);
      });

      test('should return true if the current is larger than latest', () {
        final result = updateCommand.isLocalVersion(
          current: '0.0.1',
          latest: '0.0.0',
        );

        expect(result, isTrue);
      });

      test('should return false if the current is less than latest', () {
        final result = updateCommand.isLocalVersion(
          current: '0.0.0',
          latest: '0.0.1',
        );

        expect(result, isFalse);
      });

      group('should check for + version', () {
        test('return true when current + is larger', () {
          final result = updateCommand.isLocalVersion(
            current: '0.0.0+2',
            latest: '0.0.0+1',
          );

          expect(result, isTrue);
        });

        test('return false when current + is smaller', () {
          final result = updateCommand.isLocalVersion(
            current: '0.0.0+1',
            latest: '0.0.0+2',
          );

          expect(result, isFalse);
        });

        test('return false when current + is equal', () {
          final result = updateCommand.isLocalVersion(
            current: '0.0.0+1',
            latest: '0.0.0+1',
          );

          expect(result, isFalse);
        });

        test('return true when current + is larger and latest is not +', () {
          final result = updateCommand.isLocalVersion(
            current: '0.0.0+1',
            latest: '0.0.0',
          );

          expect(result, isTrue);
        });
      });
    });
  });
}
