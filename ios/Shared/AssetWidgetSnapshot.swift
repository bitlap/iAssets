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
  private static var snapshotURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
      .appendingPathComponent("widget-snapshot-v1.json")
  }

  static func read() -> AssetWidgetSnapshot? {
    guard let url = snapshotURL,
          let data = try? Data(contentsOf: url),
          let snapshot = try? JSONDecoder().decode(AssetWidgetSnapshot.self, from: data),
          snapshot.schema == 1 else { return nil }
    return snapshot
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
    var snapshot = AssetWidgetSnapshot(
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
    if privateMode { snapshot.redact() }
    try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
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

  private static var privacyIsEnabled: Bool {
    let defaults = UserDefaults.standard
    return defaults.bool(forKey: "privacy.hideAmounts") ||
      defaults.bool(forKey: "privacy.biometricLock")
  }
}
