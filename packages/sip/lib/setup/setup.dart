import 'package:get_it/get_it.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/sip_console_setup.dart' as console;

late GetIt getIt;

void setup() {
  getIt = GetIt.asNewInstance();

  console.setup(getIt);

  getIt.registerLazySingleton<SipConsole>(SipConsole.new);
}
