import 'package:path/path.dart' as path;
import 'package:sip_cli/src/deps/find_file.dart';
import 'package:sip_cli/src/deps/pubspec_lock.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/domain/executables.dart';

class DetermineFlutterOrDart {
  DetermineFlutterOrDart(this.pubspecYaml);

  final String pubspecYaml;

  String? _tool;

  bool _isFlutter = false;
  bool get isFlutter {
    tool();

    return _isFlutter;
  }

  bool _isDart = true;
  bool get isDart {
    tool();

    return _isDart;
  }

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
      _isFlutter = true;
      _isDart = false;
    }

    return _tool = tool;
  }
}
