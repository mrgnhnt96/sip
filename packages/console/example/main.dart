import 'package:get_it/get_it.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/sip_console_setup.dart';

void main() {
  final GetIt getIt = GetIt.instance;

  setup(getIt); // This is required to run the console app

  final console = getIt<SipConsole>();

  console.d('Hello World!');
}
