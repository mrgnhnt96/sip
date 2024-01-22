import 'package:sip/utils/exit_code.dart';

abstract interface class RunScript {
  const RunScript();

  Future<ExitCode> run();
}
