import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

class PrintLog extends Print {
  PrintLog()
      : super(
          group: Group(
            tag: '-',
            color: darkGray,
          ),
        );
}
