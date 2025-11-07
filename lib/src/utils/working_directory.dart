import 'package:path/path.dart' as path;
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';

abstract mixin class WorkingDirectory {
  String _findDirectory() {
    final nearest = scriptsYaml.nearest();
    final directory = nearest == null
        ? fs.currentDirectory.path
        : path.dirname(nearest);

    return directory;
  }

  String get directory => _findDirectory();
}
