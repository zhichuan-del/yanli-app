/// Serializes full data snapshots, without assuming that the underlying store
/// can roll back a failed or interrupted write.
///
/// A false result means that the write was not confirmed; the caller must
/// retain the pending draft and can enqueue it again to retry.
class StorageSafety {
  StorageSafety(this._write);

  final Future<bool> Function(String snapshot) _write;
  Future<void> _tail = Future<void>.value();

  Future<bool> enqueue(String snapshot) {
    final result = _tail.then((_) async {
      try {
        return await _write(snapshot);
      } catch (_) {
        return false;
      }
    });
    // Every operation is resolved, even after a failure, so subsequent writes
    // are not blocked by a rejected future.
    _tail = result.then<void>((_) {});
    return result;
  }

  /// Waits for operations already enqueued when this getter is read.
  Future<void> get idle => _tail;
}
