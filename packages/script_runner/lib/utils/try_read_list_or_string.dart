import 'package:sip_script_runner/utils/logger.dart';

List<String>? tryReadListOrString(dynamic json) {
  if (json is String) {
    final trimmed = json.trim();
    if (trimmed.isEmpty) return [];

    return [trimmed];
  } else if (json is List) {
    final list = <String>[];
    for (final e in json) {
      if (e == null) continue;
      if (e is Map) {
        Logger.err(
          'The script "$e" is not a string or a list of strings',
        );
        continue;
      }

      if (e is! String) {
        list.add('$e');
        continue;
      }

      final trimmed = e.trim();
      if (trimmed.isEmpty) continue;

      list.add(trimmed);
    }

    return list;
  }

  return null;
}
