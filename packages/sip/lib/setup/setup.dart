import 'package:get_it/get_it.dart';
import 'package:sip_console/sip_console.dart' hide setup;
import 'package:sip_console/sip_console.dart' as console show setup;

late GetIt getIt;

void setup() {
  getIt = GetIt.asNewInstance();

  console.setup(getIt);

  getIt.registerLazySingleton<SipConsole>(SipConsole.new);
}
