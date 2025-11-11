import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/script_runner.dart';

final scriptRunnerProvider = create(ScriptRunner.new);

ScriptRunner get scriptRunner => read(scriptRunnerProvider);
