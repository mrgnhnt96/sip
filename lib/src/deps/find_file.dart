import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/find_file.dart';

final findFileProvider = create<FindFile>(FindFile.new);

FindFile get findFile => read(findFileProvider);
