import SwiftUI
import WidgetKit

private struct AssetWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: AssetWidgetSnapshot?
  let stale: Bool
}

private struct AssetWidgetProvider: TimelineProvider {
  private let maxAge: TimeInterval = 30 * 60

  func placeholder(in context: Context) -> AssetWidgetEntry {
    AssetWidgetEntry(date: .now, snapshot: nil, stale: false)
  }

  func getSnapshot(in context: Context, completion: @escaping (AssetWidgetEntry) -> Void) {
    let snapshot = context.isPreview ? nil : AssetWidgetSnapshotStore.read()
    completion(entry(for: snapshot, at: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<AssetWidgetEntry>) -> Void) {
    let now = Date()
    let snapshot = AssetWidgetSnapshotStore.read()
    var entries = [entry(for: snapshot, at: now)]
    if let snapshot {
      let staleAt = snapshot.updatedAt.addingTimeInterval(maxAge)
      if staleAt > now {
        entries.append(entry(for: snapshot, at: staleAt))
      }
    }
    // 数据或隐私设置变化后，应用发布新快照并调用 WidgetCenter。
    // 第二个时间线条目用于更新界面上的过期状态标记。
    completion(Timeline(entries: entries, policy: .atEnd))
  }

  private func entry(for snapshot: AssetWidgetSnapshot?, at date: Date) -> AssetWidgetEntry {
    AssetWidgetEntry(
      date: date,
      snapshot: snapshot,
      stale: snapshot.map { date.timeIntervalSince($0.updatedAt) >= maxAge } ?? false
    )
  }
}

private enum WidgetWords {
  static func language(_ snapshot: AssetWidgetSnapshot?) -> String {
    if let language = snapshot?.language { return language }
    let locale = Locale.current
    guard locale.language.languageCode?.identifier == "zh" else { return "en" }
    if locale.language.script?.identifier == "Hant" ||
        ["TW", "HK", "MO"].contains(locale.region?.identifier ?? "") {
      return "zh_Hant"
    }
    return "zh"
  }

  static func text(_ key: String, _ language: String) -> String {
    let words: [String: [String: String]] = [
      "total": ["zh": "总资产", "zh_Hant": "總資產", "en": "Total assets"],
      "stocks": ["zh": "股票", "zh_Hant": "股票", "en": "Stocks"],
      "crypto": ["zh": "数字币", "zh_Hant": "數字幣", "en": "Crypto"],
      "other": ["zh": "其他资产", "zh_Hant": "其他資產", "en": "Other"],
      "updated": ["zh": "更新于", "zh_Hant": "更新於", "en": "Updated"],
      "stale": ["zh": "已过期", "zh_Hant": "已過期", "en": "Stale"],
      "incomplete": ["zh": "估值不完整", "zh_Hant": "估值不完整", "en": "Incomplete"],
      "empty": ["zh": "打开 App 更新", "zh_Hant": "開啟 App 更新", "en": "Open app to update"],
      "hidden": ["zh": "金额已隐藏", "zh_Hant": "金額已隱藏", "en": "Amounts hidden"],
      "description": [
        "zh": "查看总资产、组合摘要及更新时间。",
        "zh_Hant": "查看總資產、組合摘要及更新時間。",
        "en": "See your total assets, portfolio summary, and update time."
      ]
    ]
    return words[key]?[language] ?? words[key]?["en"] ?? key
  }
}

private struct AssetWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(AssetWidgetSnapshotStore.hideAmountsKey,
              store: UserDefaults(suiteName: AssetWidgetSnapshotStore.group))
  private var hideAmounts = false
  @AppStorage(AssetWidgetSnapshotStore.biometricLockKey,
              store: UserDefaults(suiteName: AssetWidgetSnapshotStore.group))
  private var biometricLock = false
  let entry: AssetWidgetEntry

  private var language: String { WidgetWords.language(entry.snapshot) }
  private func word(_ key: String) -> String { WidgetWords.text(key, language) }
  private var isHidden: Bool {
    (entry.snapshot?.hidden ?? false) || hideAmounts || biometricLock
  }
  private var total: String {
    if isHidden { return "••••" }
    return entry.snapshot?.total ?? "—"
  }
  private var status: String {
    if isHidden { return word("hidden") }
    guard let snapshot = entry.snapshot else { return word("empty") }
    if snapshot.incomplete { return word("incomplete") }
    if entry.stale { return word("stale") }
    return word("updated")
  }
  private var updateTime: String? {
    guard let snapshot = entry.snapshot else { return nil }
    return snapshot.formattedUpdateTime(language: language)
  }
  private var updateLine: String? {
    updateTime.map { "\(word("updated")) \($0)" }
  }

  var body: some View {
    Group {
      switch family {
      case .accessoryInline: inlineView
      case .accessoryRectangular: lockView
      case .systemSmall: homeView(size: .small)
      default: homeView(size: .medium)
      }
    }
    .widgetURL(URL(string: "iassets://assets"))
  }

  private var inlineView: some View {
    HStack(spacing: 3) {
      Image(systemName: "chart.pie.fill")
      Text(word("total"))
      Text(total).privacySensitive()
      if entry.stale { Text("· \(word("stale"))") }
    }
    .lineLimit(1)
    .minimumScaleFactor(0.8)
  }

  private var lockView: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Image(systemName: "chart.pie.fill")
        Text(word("total"))
        Spacer(minLength: 0)
        if entry.stale || entry.snapshot?.incomplete == true {
          Image(systemName: "exclamationmark.circle.fill")
        }
      }
      .font(.system(size: 12, weight: .semibold))
      Text(total)
        .font(.system(size: 23, weight: .bold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .privacySensitive()
      VStack(spacing: 0) {
        if status != word("updated") { Text(status) }
        if let updateLine { Text(updateLine) }
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .multilineTextAlignment(.center)
      .font(.system(size: 11))
      .lineLimit(1)
      .minimumScaleFactor(0.7)
    }
    .accessibilityElement(children: .combine)
  }

  private enum HomeSize { case small, medium }

  @ViewBuilder
  private func homeView(size: HomeSize) -> some View {
    let content = VStack(alignment: .leading, spacing: 0) {
      header(showCurrency: size != .small)
      Spacer(minLength: 3)
      if size == .medium {
        totalAmount(size: size)
        Spacer(minLength: 3)
        HStack(alignment: .top, spacing: 10) {
          breakdown("stocks", value: entry.snapshot?.stocks, color: .blue)
          breakdown("crypto", value: entry.snapshot?.crypto, color: .purple)
          breakdown("other", value: entry.snapshot?.other, color: .orange)
        }
      } else {
        totalAmount(size: size)
      }
      Spacer(minLength: 3)
      statusRow(size: size)
    }
    .padding(.horizontal, size == .small ? 11 : 12)
    .padding(.vertical, 9)

    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) { background }
    } else {
      content.background(background)
    }
  }

  private func header(showCurrency: Bool) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "chart.pie.fill")
        .foregroundStyle(Color(red: 0.56, green: 0.34, blue: 0.86))
      Text("iAssets")
        .font(.system(size: 17, weight: .bold))
      Spacer(minLength: 0)
      if showCurrency {
        Text(entry.snapshot?.currency ?? "")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
  }

  private func totalAmount(size: HomeSize) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(word("total"))
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.secondary)
      Text(total)
        .font(.system(size: size == .small ? 32 : 36,
                      weight: .bold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .privacySensitive()
    }
  }

  @ViewBuilder
  private func statusRow(size: HomeSize) -> some View {
    if size == .small {
      VStack(spacing: 1) {
        if status != word("updated") { Text(status) }
        Text(updateLine ?? status)
      }
      .frame(maxWidth: .infinity, alignment: .center)
      .multilineTextAlignment(.center)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
    } else {
      ZStack(alignment: .leading) {
        if updateLine != nil && status != word("updated") {
          Text(status)
            .frame(maxWidth: 80, alignment: .leading)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        Text(updateLine ?? status)
          .frame(maxWidth: .infinity, alignment: .center)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .accessibilityLabel(status == word("updated") ? updateLine ?? status : "\(status)，\(updateLine ?? "")")
    }
  }

  private var background: some View {
    LinearGradient(
      colors: colorScheme == .dark
        ? [Color(red: 0.14, green: 0.12, blue: 0.19), Color(red: 0.10, green: 0.15, blue: 0.19)]
        : [Color(red: 0.97, green: 0.95, blue: 1.0), Color(red: 0.94, green: 0.98, blue: 1.0)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private func breakdown(_ key: String, value: String?, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 3) {
        Circle().fill(color).frame(width: 6, height: 6)
        Text(word(key)).lineLimit(1).minimumScaleFactor(0.9)
      }
      .font(.system(size: 14, weight: .medium))
      .foregroundStyle(.secondary)
      Text(isHidden ? "••••" : (value ?? "—"))
        .font(.system(size: 17, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .privacySensitive()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct AssetSummaryWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: AssetWidgetSnapshotStore.widgetKind, provider: AssetWidgetProvider()) {
      AssetWidgetView(entry: $0)
    }
    .configurationDisplayName("iAssets")
    .description(WidgetWords.text("description", WidgetWords.language(nil)))
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular,
                        .accessoryInline])
    .contentMarginsDisabled()
  }
}

@main
struct AssetsWidgetBundle: WidgetBundle {
  var body: some Widget { AssetSummaryWidget() }
}
