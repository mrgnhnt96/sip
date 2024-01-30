/// When a task is finished, it can be in one of three states: success, failure, or cancelled.
enum FinisherType {
  /// The task was successful.
  success,

  /// The task failed.
  failure,

  /// The task was cancelled.
  cancelled,
}

/// A finisher is a callback that can be called to indicate that a task has finished.
abstract class Finisher {
  const Finisher();

  /// Successfully finish the task.
  void call();

  /// Finish the task with a failure.
  void fail();

  /// Cancel the task.
  void cancel();
}

/// Implementation of the [Finisher] interface.
class FinisherImpl implements Finisher {
  const FinisherImpl({
    required void Function(FinisherType) finish,
  }) : _finish = finish;

  final void Function(FinisherType) _finish;

  @override
  void call() {
    _finish(FinisherType.success);
  }

  @override
  void fail() {
    _finish(FinisherType.failure);
  }

  @override
  void cancel() {
    _finish(FinisherType.cancelled);
  }
}

/// A collection of finishers.
class Finishers {
  const Finishers(this.finishers);

  final Iterable<Finisher> finishers;

  /// Finish all tasks successfully.
  void all() {
    finishers.forEach((e) => e());
  }

  /// Fail all tasks.
  void failAll() {
    finishers.forEach((e) => e.fail());
  }

  /// Cancel all tasks.
  void cancelAll() {
    finishers.forEach((e) => e.cancel());
  }

  /// Get the finisher at the given index.
  operator [](int index) => finishers.elementAt(index);
}
