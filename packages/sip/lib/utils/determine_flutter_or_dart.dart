import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/executables.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';

class DetermineFlutterOrDart {
  DetermineFlutterOrDart({
    required this.pubspecYaml,
    required this.pubspecLock,
    required this.findFile,
    required this.scriptsYaml,
  });

  final FindFile findFile;
  final String pubspecYaml;
  final PubspecLock pubspecLock;
  final ScriptsYaml scriptsYaml;

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

  String tool() {
    if (_tool != null) {
      return _tool!;
    }

    final root = path.dirname(pubspecYaml);

    final nestedLock = pubspecLock.findIn(root);

    final executables = Executables.fromJson(scriptsYaml.executables() ?? {});

    var tool = executables.dart ?? 'dart';

    final contents = findFile.retrieveContent(nestedLock ?? pubspecYaml);

    if (contents != null && contents.contains('flutter')) {
      tool = executables.flutter ?? 'flutter';
    }

    return _tool = tool;
  }
}
