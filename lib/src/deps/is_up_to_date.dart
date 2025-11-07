import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/is_up_to_date.dart';

final isUpToDateProvider = create<IsUpToDate>(IsUpToDate.new);

IsUpToDate get isUpToDate => read(isUpToDateProvider);
