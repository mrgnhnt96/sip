import 'package:sip_console/sip_console.dart';
import 'package:sip_console/sip_console_setup.dart';

void main() {
  setup(); // This is required to run the console app

  final console = SipConsole();

  console.d('Hello World!');
}
