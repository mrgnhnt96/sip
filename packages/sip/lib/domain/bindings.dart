// ignore_for_file: one_member_abstracts
import 'package:sip_cli/domain/command_result.dart';

/// The bindings for the script runner
///
/// This is the interface that the script runner
/// uses to interact with the outside (rust) world
abstract interface class Bindings {
  const Bindings();

  Future<CommandResult> runScript(String script, {required bool showOutput});
}
