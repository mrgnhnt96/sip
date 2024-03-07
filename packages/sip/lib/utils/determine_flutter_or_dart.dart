import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class DetermineFlutterOrDart {
  DetermineFlutterOrDart({
    required this.pubspecYaml,
    required this.pubspecLock,
    required this.findFile,
  });

  final FindFile findFile;
  final String pubspecYaml;
  final PubspecLock pubspecLock;

  String? _tool;

  bool get isFlutter => tool() == 'flutter';
  bool get isDart => tool() == 'dart';

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
