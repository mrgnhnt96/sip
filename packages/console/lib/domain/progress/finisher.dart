enum FinisherType {
  success,
  failure,
  cancelled,
}

abstract class Finisher {
  const Finisher();

  void call();

  void fail();

  void cancel();
}

class FinisherImpl implements Finisher {
  const FinisherImpl({
    required void Function(FinisherType) finish,
  }) : _finish = finish;

  final void Function(FinisherType) _finish;

  void call() {
    _finish(FinisherType.success);
  }

  void fail() {
    _finish(FinisherType.failure);
  }

  void cancel() {
    _finish(FinisherType.cancelled);
  }
}

class Finishers {
  const Finishers(this.finishers);

  final Iterable<Finisher> finishers;

  void all() {
    finishers.forEach((e) => e());
  }

  void failAll() {
    finishers.forEach((e) => e.fail());
  }

  void cancelAll() {
    finishers.forEach((e) => e.cancel());
  }

  operator [](int index) => finishers.elementAt(index);
}
