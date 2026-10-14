import 'dart:async';

/// Mimics a `huawei_push` event channel: one handler per channel, a new listen replaces it and any cancel clears it.
class FakePluginEventChannel<T> {
  void Function(T value)? _onData;
  void Function(Object error)? _onError;

  int listenCount = 0;
  int cancelCount = 0;

  /// Like `Push.getTokenStream`: every access is a fresh stream over the same channel.
  Stream<T> get stream => Stream<T>.multi((controller) {
    listenCount++;
    _onData = controller.add;
    _onError = controller.addError;
    controller.onCancel = () {
      cancelCount++;
      _onData = null;
      _onError = null;
    };
  });

  /// Whether a handler is currently registered.
  bool get hasHandler => _onData != null;

  /// Delivers [value] to the registered handler, if any.
  void emit(T value) => _onData?.call(value);

  /// Delivers [error] to the registered handler, if any.
  void emitError(Object error) => _onError?.call(error);
}
