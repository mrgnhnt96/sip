import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

class PrintWarn extends Print {
  PrintWarn()
      : super(
          group: Group(
            tag: '⚠',
            color: lightYellow,
          ),
        );
}
