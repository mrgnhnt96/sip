import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/time.dart';

final timeProvider = create(Time.new);

Time get time => read(timeProvider);
