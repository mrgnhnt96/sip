import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/bindings.dart';

final bindingsProvider = create<Bindings>(Bindings.new);

Bindings get bindings => read(bindingsProvider);
