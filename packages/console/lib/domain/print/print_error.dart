import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

class PrintError extends Print {
  PrintError()
      : super(
          group: Group(
            name: 'Error',
            color: lightRed,
          ),
        );
}
