import 'dart:math';

extension ListTX<T> on List<T> {
  List<List<T>> chunked(int count) {
    final chunks = <List<T>>[];

    for (var i = 0; i < length; i += count) {
      chunks.add(sublist(i, min(i + count, length)));
    }

    return chunks;
  }
}
