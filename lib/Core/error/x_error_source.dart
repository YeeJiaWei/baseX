/// Where an error entered XExceptionHandler.
enum XErrorSource {
  /// Thrown inside BaseXController.run.
  action,

  /// Escaped to PlatformDispatcher.onError (uncaught async or platform error).
  uncaught,

  /// Reported through FlutterError.onError (build, layout, paint, gesture).
  widget,
}
