import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock_impl.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:path/path.dart' as path;

class DetermineFlutterOrDart {
  const DetermineFlutterOrDart({
    required this.pubspecYaml,
    PubspecLock pubspecLock = const PubspecLockImpl(),
    FindFile findFile = const FindFile(),
  })  : _findFile = findFile,
        _pubspecLock = pubspecLock;

  final FindFile _findFile;
  final String pubspecYaml;
  final PubspecLock _pubspecLock;

  String tool() {
    final root = path.dirname(pubspecYaml);

    final nestedLock = _pubspecLock.findIn(root);

    var tool = 'dart';

    final contents = _findFile.retrieveContent(nestedLock ?? pubspecYaml);

    if (contents != null && contents.contains('flutter')) {
      tool = 'flutter';
    }

    return tool;
  }
}
