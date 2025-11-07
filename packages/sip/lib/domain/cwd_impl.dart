import 'package:file/file.dart';
import 'package:sip_cli/domain/cwd.dart';

class CWDImpl implements CWD {
  const CWDImpl({required this.fs});

  final FileSystem fs;

  @override
  String get path => fs.currentDirectory.path;
}
