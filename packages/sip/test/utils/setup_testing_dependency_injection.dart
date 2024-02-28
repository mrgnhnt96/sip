import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_console/sip_console.dart';

void setupTestingDependencyInjection() {
  final getIt = GetIt.asNewInstance();

  getIt.registerLazySingleton<FileSystem>(() => MemoryFileSystem());
  getIt.registerLazySingleton<SipConsole>(() => _SipConsoleMock());

  setup(getIt);
}

class _SipConsoleMock extends Mock implements SipConsole {}
