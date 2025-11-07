import 'package:sip_cli/src/domain/args.dart';

class FakeArgs extends Args {
  @override
  List<String> rest = [];
  @override
  List<String> path = [];
  @override
  List<String> original = [];
  @override
  List<String> rawArgs = [];
  @override
  Map<String, dynamic> values = {};

  void operator []=(String key, dynamic value) {
    values[key] = value;
  }
}
