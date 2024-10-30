import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/cwd.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';

abstract mixin class WorkingDirectory {
  ScriptsYaml get scriptsYaml;
  CWD get cwd;

  String? _directory;
  String _findDirectory() {
    final nearest = scriptsYaml.nearest();
    final directory = nearest == null ? cwd.path : path.dirname(nearest);

    return directory;
  }

  String get directory => _directory ??= _findDirectory();
}
