// dart format width=120
// ignore_for_file: lines_longer_than_80_chars
import 'package:meta/meta.dart';
import 'package:sip_cli/src/deps/args.dart';

class FlutterAndDartArgs {
  const FlutterAndDartArgs();

  int? get concurrent => args.getOrNull<int>('concurrency', abbr: 'j');
  String? get excludeTags => args.getOrNull<String>('exclude-tags', abbr: 'x');
  String? get fileReporter => args.getOrNull<String>('file-reporter');
  List<String>? get name => args.getOrNull<List<String>>('name', abbr: 'n');
  List<String>? get plainName => args.getOrNull<List<String>>('plain-name', abbr: 'N');
  String? get reporter => args.getOrNull<String>('reporter');
  bool get runSkipped => args.get<bool>('run-skipped', defaultValue: false);
  int? get shardIndex => args.getOrNull<int>('shard-index');
  int? get totalShards => args.getOrNull<int>('total-shards');
  List<String>? get tags => args.getOrNull<List<String>>('tags', abbr: 't');
  String? get testRandomizeOrderingSeed => args.getOrNull<String>('test-randomize-ordering-seed');
  String? get timeout => args.getOrNull<String>('timeout');

  @mustCallSuper
  List<String> get arguments {
    Iterable<String> arguments() sync* {
      if (concurrent case final int concurrent) {
        yield '--concurrent $concurrent';
      }

      if (excludeTags case final String excludeTags) {
        yield '--exclude-tags $excludeTags';
      }

      if (name case final List<String> name) {
        yield '--name ${name.join(',')}';
      }

      if (plainName case final List<String> plainName) {
        yield '--plain-name ${plainName.join(',')}';
      }

      if (reporter case final String reporter) {
        yield '--reporter $reporter';
      }

      if (runSkipped) {
        yield '--run-skipped';
      }

      if (shardIndex case final int shardIndex) {
        yield '--shard-index $shardIndex';
      }

      if (totalShards case final int totalShards) {
        yield '--total-shards $totalShards';
      }

      if (tags case final List<String> tags) {
        yield '--tags ${tags.join(',')}';
      }

      if (testRandomizeOrderingSeed case final String testRandomizeOrderingSeed) {
        yield '--test-randomize-ordering-seed $testRandomizeOrderingSeed';
      }

      if (timeout case final String timeout) {
        yield '--timeout $timeout';
      }
    }

    return arguments().toList();
  }
}
