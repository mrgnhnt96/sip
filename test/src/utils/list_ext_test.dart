import 'package:sip_cli/src/utils/list_ext.dart';
import 'package:test/test.dart';

void main() {
  group('ListTX', () {
    group('#chunked', () {
      test('splits a list into chunks of the given size', () {
        final result = [1, 2, 3, 4, 5].chunked(2);

        expect(result, [
          [1, 2],
          [3, 4],
          [5],
        ]);
      });
    });

    group('#shard', () {
      test('deterministically round-robins items across shards', () {
        final items = ['a', 'b', 'c', 'd', 'e'];

        expect(items.shard(index: 0, count: 2), ['a', 'c', 'e']);
        expect(items.shard(index: 1, count: 2), ['b', 'd']);
      });

      test('every item appears in exactly one shard', () {
        final items = List.generate(17, (i) => i);
        const count = 4;

        final shards = [
          for (var i = 0; i < count; i++) items.shard(index: i, count: count),
        ];

        expect(shards.expand((s) => s).toSet(), items.toSet());
        expect(shards.expand((s) => s).length, items.length);
      });

      test('returns the whole list when count is 1', () {
        final items = [1, 2, 3];

        expect(items.shard(index: 0, count: 1), items);
      });

      test('returns an empty list for a shard past the item count', () {
        final items = [1, 2];

        expect(items.shard(index: 5, count: 6), isEmpty);
      });

      test('throws when count is less than 1', () {
        expect(
          () => [1, 2].shard(index: 0, count: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws when index is out of range', () {
        expect(
          () => [1, 2].shard(index: 2, count: 2),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => [1, 2].shard(index: -1, count: 2),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
