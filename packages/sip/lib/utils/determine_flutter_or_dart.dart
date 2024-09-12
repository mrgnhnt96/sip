import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';

class DetermineFlutterOrDart {
  DetermineFlutterOrDart({
    required this.pubspecYaml,
    required this.pubspecLock,
    required this.findFile,
  }) : testType = null;

  DetermineFlutterOrDart._({
    required this.pubspecYaml,
    required this.pubspecLock,
    required this.findFile,
    required this.testType,
  });

  final FindFile findFile;
  final String pubspecYaml;
  final PubspecLock pubspecLock;
  final String? testType;

  String? _tool;

  bool get isFlutter => tool() == 'flutter';
  bool get isDart => tool() == 'dart';

  String directory({String? fromDirectory}) {
    final dir = path.dirname(pubspecYaml);

    if (fromDirectory == null) {
      return dir;
    }

    return path.relative(dir, from: fromDirectory);
  }

  DetermineFlutterOrDart setTestType(String testType) {
    if (testType == 'dart' || testType == 'flutter') {
      return this;
    }

    return DetermineFlutterOrDart._(
      pubspecYaml: pubspecYaml,
      pubspecLock: pubspecLock,
      findFile: findFile,
      testType: testType,
    );
  }

  String tool() {
    if (_tool != null) {
      return _tool!;
    }

    final root = path.dirname(pubspecYaml);

    final nestedLock = pubspecLock.findIn(root);

    var tool = 'dart';

    final contents = findFile.retrieveContent(nestedLock ?? pubspecYaml);

    if (contents != null && contents.contains('flutter')) {
      tool = 'flutter';
    }

    return _tool = tool;
  }
}
