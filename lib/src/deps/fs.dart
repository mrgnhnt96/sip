import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:scoped_deps/scoped_deps.dart';

final fsProvider = create<FileSystem>(LocalFileSystem.new);

FileSystem get fs => read(fsProvider);
