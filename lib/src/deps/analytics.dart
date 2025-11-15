import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/analytics.dart';

final analyticsProvider = create(Analytics.new);

Analytics get analytics => read(analyticsProvider);
