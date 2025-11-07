import 'package:mason_logger/mason_logger.dart';

List<String>? tryReadListOrString(dynamic json) {
  final logger = Logger();

  if (json is String) {
    final trimmed = json.trim();
    if (trimmed.isEmpty) return [];

    return [trimmed];
  } else if (json is List) {
    final list = <String>[];
    for (final e in json) {
      if (e == null) continue;
      if (e is Map) {
        logger.err('The script "$e" is not a string or a list of strings');
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
