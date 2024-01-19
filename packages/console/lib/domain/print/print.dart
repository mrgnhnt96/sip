import 'package:dart_console2/dart_console2.dart';
import 'package:sip_console/setup/setup.dart';
import 'package:sip_console/utils/ansi.dart';

abstract class Print {
  const Print({
    required Group this.group,
  });
  const Print.noGroup() : group = null;

  final Group? group;

  void print(String message) {
    final console = getIt<Console>();

    final msg = group == null ? message : '$group $message';

    console.writeLine(msg);
  }
}

class Group {
  const Group({
    required this.name,
    required this.color,
  });
  const Group.name(String this.name) : color = null;

  final String? name;
  final AnsiCode? color;

  @override
  String toString() {
    final group = '$name:';

    final color = this.color;
    if (color == null) return group;

    return color.wrap(group) ?? group;
  }
}
