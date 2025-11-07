import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/run_many_scripts.dart';

final runManyScriptsProvider = create<RunManyScripts>(RunManyScripts.new);

RunManyScripts get runManyScripts => read(runManyScriptsProvider);
