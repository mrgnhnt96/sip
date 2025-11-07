import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/variables.dart';

final variablesProvider = create<Variables>(Variables.new);

Variables get variables => read(variablesProvider);
