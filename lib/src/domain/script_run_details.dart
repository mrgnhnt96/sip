import 'package:sip_cli/src/domain/command_result.dart';

class ScriptRunDetails {
  ScriptRunDetails({required Future<CommandResult> result, required this.kill})
    : _future = result;

  CommandResult? _result;
  final Future<CommandResult> _future;
  Future<CommandResult> get result async {
    if (_result case final result?) {
      return result;
    }

    return _future;
  }

  final void Function() kill;
}
