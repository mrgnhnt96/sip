import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/run_one_script.dart';

final runOneScriptProvider = create<RunOneScript>(RunOneScript.new);

RunOneScript get runOneScript => read(runOneScriptProvider);
