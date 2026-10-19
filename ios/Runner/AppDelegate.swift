import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureScreenEnabled = false
  private var privacyView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NovelPhoneSecurity") {
      let channel = FlutterMethodChannel(
        name: "novelphone/security",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "setSecureScreen" {
          let arguments = call.arguments as? [String: Any]
          self?.secureScreenEnabled = arguments?["enabled"] as? Bool ?? false
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  // 应用失活时立刻用不透明遮罩覆盖窗口，避免系统快照与任务切换器泄露正文。
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    guard secureScreenEnabled, privacyView == nil, let window = self.window else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .systemBackground
    window.addSubview(overlay)
    privacyView = overlay
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    privacyView?.removeFromSuperview()
    privacyView = nil
  }
}
