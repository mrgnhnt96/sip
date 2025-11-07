import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/find.dart';

final findProvider = create<Find>(Find.new);

Find get find => read(findProvider);
