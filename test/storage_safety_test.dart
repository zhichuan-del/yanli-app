import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/storage_safety.dart';

void main() {
  test('按提交顺序串行写入，前一笔完成前不开始下一笔', () async {
    final calls = <String>[];
    final first = Completer<bool>();
    final store = StorageSafety((snapshot) async {
      calls.add(snapshot);
      if (snapshot == 'first') return first.future;
      return true;
    });
    final a = store.enqueue('first');
    final b = store.enqueue('second');
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['first']);
    first.complete(true);
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(calls, ['first', 'second']);
    await store.idle;
  });

  test('写入返回 false 时可重试，失败不会阻塞后续快照', () async {
    final calls = <String>[];
    final store = StorageSafety((snapshot) async {
      calls.add(snapshot);
      return calls.length != 1;
    });
    expect(await store.enqueue('draft'), isFalse);
    expect(await store.enqueue('draft'), isTrue);
    expect(await store.enqueue('later'), isTrue);
    expect(calls, ['draft', 'draft', 'later']);
  });

  test('写入抛异常视为未确认，后续写入仍能继续', () async {
    var calls = 0;
    final store = StorageSafety((snapshot) async {
      calls++;
      if (calls == 1) throw StateError('未确认保存');
      return true;
    });
    expect(await store.enqueue('draft'), isFalse);
    expect(await store.enqueue('draft'), isTrue);
    expect(calls, 2);
  });
}
