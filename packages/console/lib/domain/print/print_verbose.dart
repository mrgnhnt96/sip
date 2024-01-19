import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

class PrintVerbose extends Print {
  PrintVerbose()
      : super(
          group: Group(
            name: '[V]',
            color: lightBlue,
          ),
        );
}
