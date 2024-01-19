import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

class PrintSuccess extends Print {
  PrintSuccess()
      : super(
            group: Group(
          name: 'Success',
          color: lightGreen,
        ));
}
