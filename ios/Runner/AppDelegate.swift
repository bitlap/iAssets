import BackgroundTasks
import Flutter
import UIKit
import Security
import StoreKit
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

    let proChannel = FlutterMethodChannel(
      name: "org.bitlap.assets/pro", binaryMessenger: flutterEngine.binaryMessenger)
    proChannel.setMethodCallHandler { call, result in
      Task { @MainActor in await ProStore.shared.handle(call, result: result) }
    }
    ProStore.shared.observe(channel: proChannel)

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

/// Pure eligibility rules shared by the StoreKit adapter and native unit tests.
/// VerificationResult must be checked by the caller before passing any facts in.
enum ProEntitlementPolicy {
  static let monthly = "org.bitlap.assets.pro.monthly"
  static let yearly = "org.bitlap.assets.pro.yearly"
  static let lifetime = "org.bitlap.assets.pro.lifetime"
  static let ids: Set<String> = [monthly, yearly, lifetime]

  static func grantsLegacy(bundleID: String, expectedBundleID: String?,
                           environment: AppStore.Environment, originalPurchaseDate: Date,
                           cutoff: Date?) -> Bool {
    guard let cutoff, bundleID == expectedBundleID, environment == .production else { return false }
    return originalPurchaseDate < cutoff
  }

  static func grantsLifetime(productID: String, productType: Product.ProductType,
                             revoked: Bool, upgraded: Bool) -> Bool {
    productID == lifetime && productType == .nonConsumable && !revoked && !upgraded
  }

  static func subscriptionExpiry(productID: String, productType: Product.ProductType,
                                 revoked: Bool, upgraded: Bool, expiration: Date?,
                                 now: Date) -> Date? {
    guard productID == monthly || productID == yearly,
          productType == .autoRenewable, !revoked, !upgraded,
          let expiration, expiration > now else { return nil }
    return expiration
  }

  static func kind(legacy: Bool, lifetime: Bool, expiry: Date?, now: Date) -> String {
    if legacy { return "legacy" }
    if lifetime { return "lifetime" }
    return expiry.map { $0 > now } == true ? "subscription" : "free"
  }
}

/// StoreKit owns and verifies entitlements. Nothing in an imported backup can
/// grant Pro, and an existing installation/data file isn't proof of ownership.
@MainActor
private final class ProStore {
  static let shared = ProStore()
  private let monthly = ProEntitlementPolicy.monthly
  private let yearly = ProEntitlementPolicy.yearly
  private let lifetime = ProEntitlementPolicy.lifetime
  private var ids: Set<String> { ProEntitlementPolicy.ids }
  private var products: [Product] = []
  private var cutoff: Date?
  private var observer: Task<Void, Never>?
  private var channel: FlutterMethodChannel?
  private var purchasing = false

  func observe(channel: FlutterMethodChannel) {
    self.channel = channel
    guard observer == nil else { return }
    observer = Task { [weak self] in
      for await verification in Transaction.updates {
        guard let self, case .verified(let transaction) = verification,
              self.ids.contains(transaction.productID) else { continue }
        await transaction.finish()
        self.channel?.invokeMethod("changed", arguments: nil)
      }
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    do {
      switch call.method {
      case "status":
        let args = call.arguments as? [String: Any]
        let formatter = ISO8601DateFormatter()
        let raw = args?["legacyCutoff"] as? String ?? ""
        cutoff = formatter.date(from: raw)
        if cutoff == nil {
          formatter.formatOptions.insert(.withFractionalSeconds)
          cutoff = formatter.date(from: raw)
        }
        result(await status())
      case "restore":
        try await AppStore.sync()
        if #available(iOS 16.0, *) { _ = try await AppTransaction.refresh() }
        result(nil)
      case "purchase":
        guard !purchasing, cutoff != nil,
              let args = call.arguments as? [String: Any],
              let id = args["id"] as? String, ids.contains(id) else {
          result("unavailable"); return
        }
        purchasing = true
        defer { purchasing = false }
        let current = await status()
        guard current["legacyVerified"] as? Bool == true else {
          result("unavailable"); return
        }
        let kind = current["kind"] as? String
        if kind == "legacy" || kind == "lifetime" ||
            (kind == "subscription" && id != lifetime) {
          result("owned"); return
        }
        guard let product = products.first(where: { $0.id == id }) else {
          result("unavailable"); return
        }
        switch try await product.purchase() {
        case .success(let verification):
          guard case .verified(let transaction) = verification else {
            result(FlutterError(code: "verification", message: "Purchase could not be verified", details: nil))
            return
          }
          await transaction.finish()
          result("success")
        case .pending: result("pending")
        case .userCancelled: result("cancelled")
        @unknown default: result("unavailable")
        }
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "storekit", message: "App Store request failed", details: nil))
    }
  }

  private func status() async -> [String: Any] {
    var kind = "free"
    var expiry: Date?
    let now = Date()
    var legacyVerified = false
    if #available(iOS 16.0, *), let cutoff {
      if let verification = try? await AppTransaction.shared,
         case .verified(let app) = verification,
         app.bundleID == Bundle.main.bundleIdentifier {
        legacyVerified = true
        // Sandbox acquisition dates are synthetic and must never grant legacy Pro.
        if ProEntitlementPolicy.grantsLegacy(
          bundleID: app.bundleID, expectedBundleID: Bundle.main.bundleIdentifier,
          environment: app.environment, originalPurchaseDate: app.originalPurchaseDate,
          cutoff: cutoff) {
          kind = "legacy"
        }
      }
    }
    var ownsLifetime = false
    for await verification in Transaction.currentEntitlements {
      guard case .verified(let transaction) = verification,
            ids.contains(transaction.productID), transaction.revocationDate == nil,
            !transaction.isUpgraded else { continue }
      if ProEntitlementPolicy.grantsLifetime(
        productID: transaction.productID, productType: transaction.productType,
        revoked: transaction.revocationDate != nil, upgraded: transaction.isUpgraded) {
        ownsLifetime = true
      } else if let date = ProEntitlementPolicy.subscriptionExpiry(
        productID: transaction.productID, productType: transaction.productType,
        revoked: transaction.revocationDate != nil, upgraded: transaction.isUpgraded,
        expiration: transaction.expirationDate, now: now) {
        expiry = max(expiry ?? date, date)
      }
    }
    // Catalog errors must not discard locally verified ownership.
    if products.isEmpty, let loaded = try? await Product.products(for: ids) {
      products = loaded
    }
    if let subscription = products.first(where: { $0.id == monthly || $0.id == yearly })?.subscription,
       let statuses = try? await subscription.status {
      for state in statuses where state.state == .inGracePeriod {
        guard case .verified(let transaction) = state.transaction,
              ids.contains(transaction.productID), transaction.revocationDate == nil,
              !transaction.isUpgraded,
              case .verified(let renewal) = state.renewalInfo,
              let date = ProEntitlementPolicy.subscriptionExpiry(
                productID: transaction.productID, productType: transaction.productType,
                revoked: transaction.revocationDate != nil, upgraded: transaction.isUpgraded,
                expiration: renewal.gracePeriodExpirationDate, now: now) else { continue }
        expiry = max(expiry ?? date, date)
      }
    }
    kind = ProEntitlementPolicy.kind(legacy: kind == "legacy", lifetime: ownsLifetime,
                                     expiry: expiry, now: now)
    var value: [String: Any] = [
      "kind": kind, "legacyVerified": legacyVerified,
      "products": products.map { ["id": $0.id, "price": $0.displayPrice] }
    ]
    if let expiry { value["expiresAt"] = ISO8601DateFormatter().string(from: expiry) }
    return value
  }
}
