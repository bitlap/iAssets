import BackgroundTasks
import Flutter
import UIKit
import Security
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  var flutterEngine: FlutterEngine!

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 14.0, *) {
      WorkmanagerDebug.setCurrent(LoggingDebugHandler())
    }

    if #available(iOS 13.0, *) {
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "profit-snapshot",
        using: nil
      ) { task in
        if let task = task as? BGAppRefreshTask {
          WorkmanagerPlugin.handlePeriodicTask(
            identifier: "profit-snapshot",
            task: task,
            earliestBeginInSeconds: 10 * 60
          )
        }
      }
    }

    flutterEngine = FlutterEngine(name: "assets engine")
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    let iCloudChannel = FlutterMethodChannel(
      name: "org.bitlap.assets/icloud",
      binaryMessenger: flutterEngine.binaryMessenger)
    iCloudChannel.setMethodCallHandler { (call, result) in
      if call.method == "getContainerUrl" {
        let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        result(url?.appendingPathComponent("Documents").path)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let cryptoChannel = FlutterMethodChannel(
      name: "org.bitlap.assets/crypto-storage",
      binaryMessenger: flutterEngine.binaryMessenger)
    cryptoChannel.setMethodCallHandler { call, result in
      CryptoStorage.handle(call, result: result)
    }

    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    window.makeKeyAndVisible()
    self.window = window

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// Connection secrets never enter Documents, iCloud or the JSON backup system.
private enum CryptoStorage {
  static let service = "org.bitlap.assets.exchange-connections"
  static var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: service,
     kSecAttrAccount as String: "connections-v1",
     kSecAttrSynchronizable as String: false]
  }

  static func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    do {
      switch call.method {
      case "readConnections":
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { result(nil); return }
        guard status == errSecSuccess, let data = item as? Data else {
          result(FlutterError(code: "keychain", message: "Keychain unavailable", details: nil)); return
        }
        result(String(data: data, encoding: .utf8))
      case "writeConnections":
        guard let value = call.arguments as? String, let data = value.data(using: .utf8) else {
          result(FlutterError(code: "arguments", message: nil, details: nil)); return
        }
        let attributes: [String: Any] = [
          kSecValueData as String: data,
          kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
          status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
          result(FlutterError(code: "keychain", message: "Keychain unavailable", details: nil)); return
        }
        result(nil)
      case "clearLegacyCache":
        let url = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: false)
          .appendingPathComponent("exchange-snapshot-v1.json")
        if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.removeItem(at: url)
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "storage", message: "Local storage unavailable", details: nil))
    }
  }
}
