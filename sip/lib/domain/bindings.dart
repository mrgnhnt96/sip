// ignore_for_file: one_member_abstracts
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/filter_type.dart';

/// The bindings for the script runner
///
/// This is the interface that the script runner
/// uses to interact with the outside (rust) world
abstract interface class Bindings {
  const Bindings();

  /// [filterType] is the type of filter to apply to the output
  Future<CommandResult> runScript(
    String script, {
    required bool showOutput,
    bool bail = false,
    FilterType? filterType,
  });
}
