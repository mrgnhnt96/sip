// dart format width=120
// ignore_for_file: lines_longer_than_80_chars
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/domain/flutter_and_dart_args.dart';

class FlutterTestArgs extends FlutterAndDartArgs {
  const FlutterTestArgs();

  bool? get experimentalFasterTesting => args.getOrNull<bool>('experimental-faster-testing');
  bool? get startPaused => args.getOrNull<bool>('start-paused');
  bool? get mergeCoverage => args.getOrNull<bool>('merge-coverage');
  bool? get branchCoverage => args.getOrNull<bool>('branch-coverage');
  String? get coveragePath => args.getOrNull<String>('coverage-path');
  List<String>? get coveragePackage => args.getOrNull<List<String>>('coverage-package');
  bool? get updateGoldens => args.getOrNull<bool>('update-goldens');
  bool get testAssets => args.get<bool>('test-assets', defaultValue: true);
  dynamic get coverage => args.getOrNull('coverage');
  bool? get noPub => true;

  @override
  List<String> get arguments {
    Iterable<String> arguments() sync* {
      yield* super.arguments;

      if (noPub case true) {
        yield '--no-pub';
      }

      if (experimentalFasterTesting case true) {
        yield '--experimental-faster-testing';
      }

      if (startPaused case true) {
        yield '--start-paused';
      }

      if (mergeCoverage case true) {
        yield '--merge-coverage';
      }

      if (branchCoverage case true) {
        yield '--branch-coverage';
      }

      if (coveragePath case final String path) {
        yield '--coverage-path $path';
      }

      if (coveragePackage case final List<String> packages) {
        yield '--coverage-package ${packages.join(',')}';
      }

      if (updateGoldens case true) {
        yield '--update-goldens';
      }

      if (testAssets) {
        yield '--test-assets';
      } else {
        yield '--no-test-assets';
      }

      if (coverage case true) {
        yield '--coverage';

        if (coveragePath case null) {
          yield '--coverage-path coverage';
        }
      } else if (coverage case final String path) {
        yield '--coverage';
        yield '--coverage-path $path';
      }
    }

    return arguments().toList();
  }
}
