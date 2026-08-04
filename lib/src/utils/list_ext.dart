import 'dart:math';

extension ListTX<T> on List<T> {
  List<List<T>> chunked(int count) {
    final chunks = <List<T>>[];

    for (var i = 0; i < length; i += count) {
      chunks.add(sublist(i, min(i + count, length)));
    }

    return chunks;
  }

  /// Deterministically selects the round-robin subset of this list that
  /// belongs to shard [index] out of [count] total shards (e.g. shard 1 of
  /// `[a, b, c, d, e]` with count 2 returns `[b, d]`).
  List<T> shard({required int index, required int count}) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'must be >= 1');
    }

    if (index < 0 || index >= count) {
      throw ArgumentError.value(index, 'index', 'must be in [0, $count)');
    }

    return [for (var i = index; i < length; i += count) this[i]];
  }
}
