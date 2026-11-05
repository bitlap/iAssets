import Foundation

struct AssetWidgetSnapshot: Codable {
  let schema: Int
  let currency: String
  let language: String
  let updatedAtMillis: Int64
  let incomplete: Bool
  var hidden: Bool
  var total: String?
  var stocks: String?
  var crypto: String?
  var other: String?

  var updatedAt: Date {
    Date(timeIntervalSince1970: TimeInterval(updatedAtMillis) / 1000)
  }

  func formattedUpdateTime(language: String, timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language == "zh_Hant" ? "zh_TW" :
                              language == "zh" ? "zh_CN" : "en_US")
    formatter.timeZone = timeZone
    formatter.dateFormat = language == "en" ? "MMM d, HH:mm:ss" : "M月d日 HH:mm:ss"
    return formatter.string(from: updatedAt)
  }

  mutating func redact() {
    hidden = true
    total = nil
    stocks = nil
    crypto = nil
    other = nil
  }
}

enum AssetWidgetSnapshotStore {
  static let group = "group.org.bitlap.assets"
  static let widgetKind = "org.bitlap.assets.summary"
  static let hideAmountsKey = "privacy.hideAmounts"
  static let biometricLockKey = "privacy.biometricLock"
  private static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: group) }
  private static var snapshotURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
      .appendingPathComponent("widget-snapshot-v1.json")
  }

  static func read() -> AssetWidgetSnapshot? {
    guard let url = snapshotURL,
          let data = try? Data(contentsOf: url),
          let snapshot = try? JSONDecoder().decode(AssetWidgetSnapshot.self, from: data),
          snapshot.schema == 1 else { return nil }
    return protectedSnapshot(snapshot, privacyEnabled: privacyIsEnabled)
  }

  static func protectedSnapshot(_ snapshot: AssetWidgetSnapshot,
                                privacyEnabled: Bool) -> AssetWidgetSnapshot {
    var copy = snapshot
    if privacyEnabled { copy.redact() }
    return copy
  }

  static func setPrivacyPreference(_ key: String, value: Bool) {
    sharedDefaults?.set(value, forKey: key)
    UserDefaults.standard.set(value, forKey: key)
  }

  /// Migrate an existing app-only setting before the widget reads its own
  /// App Group defaults. Never clear a shared flag during migration.
  static func syncEnabledPrivacyPreferences() {
    for key in [hideAmountsKey, biometricLockKey] where UserDefaults.standard.bool(forKey: key) {
      sharedDefaults?.set(true, forKey: key)
    }
  }

  static func publish(_ values: [String: Any]) throws {
    guard let url = snapshotURL,
          let schema = values["schema"] as? Int, schema == 1,
          let currency = values["currency"] as? String,
          let language = values["language"] as? String,
          let millis = (values["updatedAtMillis"] as? NSNumber)?.int64Value,
          let incomplete = values["incomplete"] as? Bool else {
      throw NSError(domain: "AssetWidgetSnapshot", code: 1)
    }
    let privateMode = privacyIsEnabled || (values["hidden"] as? Bool ?? false)
    let snapshot = AssetWidgetSnapshot(
      schema: schema,
      currency: currency,
      language: language,
      updatedAtMillis: millis,
      incomplete: incomplete,
      hidden: privateMode,
      total: values["total"] as? String,
      stocks: values["stocks"] as? String,
      crypto: values["crypto"] as? String,
      other: values["other"] as? String
    )
    let protected = protectedSnapshot(snapshot, privacyEnabled: privateMode)
    try JSONEncoder().encode(protected).write(to: url, options: .atomic)
  }

  /// Scrub persisted amounts before requesting a WidgetKit reload. A previous
  /// render may remain visible briefly because WidgetKit controls scheduling.
  static func applyPrivacy() {
    guard privacyIsEnabled, let url = snapshotURL, var snapshot = read() else { return }
    snapshot.redact()
    if let redacted = try? JSONEncoder().encode(snapshot) {
      try? redacted.write(to: url, options: .atomic)
    }
  }

  static var privacyIsEnabled: Bool {
    let local = UserDefaults.standard
    let shared = sharedDefaults
    return local.bool(forKey: hideAmountsKey) ||
      local.bool(forKey: biometricLockKey) ||
      (shared?.bool(forKey: hideAmountsKey) ?? false) ||
      (shared?.bool(forKey: biometricLockKey) ?? false)
  }
}
