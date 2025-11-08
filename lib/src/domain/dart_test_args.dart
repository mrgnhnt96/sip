// dart format width=120
// ignore_for_file: lines_longer_than_80_chars
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/domain/flutter_and_dart_args.dart';

class DartTestArgs extends FlutterAndDartArgs {
  const DartTestArgs();

  String? get platform => args.getOrNull<String>('platform', abbr: 'p');
  String? get compiler => args.getOrNull<String>('compiler');
  String? get preset => args.getOrNull<String>('preset', abbr: 'P');
  bool get ignoreTimeouts => args.get<bool>('ignore-timeouts', defaultValue: false);
  bool get pauseAfterLoad => args.get<bool>('pause-after-load', defaultValue: false);
  bool get debug => args.get<bool>('debug', defaultValue: false);
  bool get chainStackTraces => args.get<bool>('chain-stack-traces', defaultValue: false);
  bool get noRetry => args.get<bool>('no-retry', defaultValue: false);
  bool get useDataIsolateStrategy => args.get<bool>('use-data-isolate-strategy', defaultValue: false);
  bool get verboseTrace => args.get<bool>('verbose-trace', defaultValue: false);
  bool get jsTrace => args.get<bool>('js-trace', defaultValue: false);
  bool get color => args.get<bool>('color', defaultValue: false);
  bool get failFast => args.getOrNull<bool>('fail-fast') ?? args.get<bool>('bail', defaultValue: false);
  dynamic get coverage {
    if (args['coverage'] case final String dir) {
      return dir;
    }

    if (args['coverage'] case true) {
      return 'coverage';
    }

    return null;
  }

  @override
  List<String> get arguments {
    Iterable<String> arguments() sync* {
      yield* super.arguments;

      if (platform case final String platform) {
        yield '--platform $platform';
      }

      if (compiler case final String compiler) {
        yield '--compiler $compiler';
      }

      if (preset case final String preset) {
        yield '--preset $preset';
      }

      if (ignoreTimeouts) {
        yield '--ignore-timeouts';
      }

      if (pauseAfterLoad) {
        yield '--pause-after-load';
      }

      if (debug) {
        yield '--debug';
      }

      if (chainStackTraces) {
        yield '--chain-stack-traces';
      }

      if (noRetry) {
        yield '--no-retry';
      }

      if (useDataIsolateStrategy) {
        yield '--use-data-isolate-strategy';
      }

      if (verboseTrace) {
        yield '--verbose-trace';
      }

      if (jsTrace) {
        yield '--js-trace';
      }

      if (color) {
        yield '--color';
      }

      if (failFast) {
        yield '--fail-fast';
      }

      if (coverage case final String coverage) {
        yield '--coverage $coverage';
      }
    }

    return arguments().toList();
  }
}
