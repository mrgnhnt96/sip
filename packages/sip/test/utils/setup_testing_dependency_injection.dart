import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sip/setup/setup.dart';

void setupTestingDependencyInjection() {
  setup();

  getIt.registerLazySingleton<FileSystem>(() => MemoryFileSystem());
}
