import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

class PrintDebug extends Print {
  PrintDebug()
      : super(
          group: Group(
            name: '[D]',
            color: lightCyan,
          ),
        );
}
