import 'package:file/file.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_script_runner/domain/cwd.dart';

class CWDImpl implements CWD {
  const CWDImpl();

  @override
  String get path => getIt<FileSystem>().currentDirectory.path;
}
