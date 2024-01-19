import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sip/setup/dependency_injection.dart';

void setupTestingDependencyInjection() {
  setupDependencyInjection();

  getIt.registerLazySingleton<FileSystem>(() => MemoryFileSystem());
}
