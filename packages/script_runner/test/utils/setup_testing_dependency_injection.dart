import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_script_runner/setup.dart';

void setupTestingDependencyInjection() {
  final getIt = GetIt.asNewInstance();

  getIt.registerLazySingleton<SipConsole>(() => _SipConsoleMock());

  setup(getIt);
}

class _SipConsoleMock extends Mock implements SipConsole {}
