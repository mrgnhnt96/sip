import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/args.dart';

final argsProvider = create<Args>(Args.new);

Args get args => read(argsProvider);
