import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/test_reports.dart';

final testReportsProvider = create(TestReports.new);

TestReports get testReports => read(testReportsProvider);
