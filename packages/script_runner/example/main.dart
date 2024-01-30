import 'package:sip_script_runner/src/bindings/bindings_impl.dart';

void main() async {
  final bindings = BindingsImpl();

  final exitCode = await bindings.runScript('print("Hello, World!")');

  print('Exit code: $exitCode');
}
