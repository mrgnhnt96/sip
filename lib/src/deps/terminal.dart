import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/terminal.dart';

final terminalProvider = create<Terminal>(Terminal.new);

Terminal get terminal => read(terminalProvider);
