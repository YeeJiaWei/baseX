import Flutter
import UIKit

/// Exposes the OS display-zoom factor on `basex/display`.
public class BaseXPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "basex/display", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(BaseXPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "zoomFactor":
      let screen = UIScreen.main
      result(screen.nativeScale > screen.scale ? Double(screen.nativeScale / screen.scale) : 1.0)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
