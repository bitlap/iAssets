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
    // The app publishes a new snapshot and calls WidgetCenter after data or
    // privacy changes. The second entry updates the visible stale marker.
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
  let entry: AssetWidgetEntry

  private var language: String { WidgetWords.language(entry.snapshot) }
  private func word(_ key: String) -> String { WidgetWords.text(key, language) }
  private var isHidden: Bool { entry.snapshot?.hidden ?? false }
  private var total: String {
    if isHidden { return "••••" }
    return entry.snapshot?.total ?? "—"
  }
  private var status: String {
    guard let snapshot = entry.snapshot else { return word("empty") }
    if snapshot.hidden { return word("hidden") }
    if snapshot.incomplete { return word("incomplete") }
    if entry.stale { return word("stale") }
    return word("updated")
  }
  private var statusColor: Color {
    entry.snapshot == nil || entry.stale || entry.snapshot?.incomplete == true
      ? Color.orange : Color.green
  }
  private var updateTime: String? {
    guard let snapshot = entry.snapshot else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: language == "zh_Hant" ? "zh_TW" : language)
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: snapshot.updatedAt)
  }

  var body: some View {
    Group {
      switch family {
      case .accessoryInline: inlineView
      case .accessoryRectangular: lockView
      case .systemSmall: homeView(size: .small)
      case .systemMedium: homeView(size: .medium)
      default: homeView(size: .large)
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
      HStack(spacing: 3) {
        Text(status)
        if let updateTime { Text("· \(updateTime)") }
      }
      .font(.system(size: 11))
      .lineLimit(1)
    }
    .accessibilityElement(children: .combine)
  }

  private enum HomeSize { case small, medium, large }

  @ViewBuilder
  private func homeView(size: HomeSize) -> some View {
    let content = VStack(alignment: .leading, spacing: size == .small ? 5 : 8) {
      header(showCurrency: size != .small)
      Spacer(minLength: 0)
      if size == .medium {
        HStack(alignment: .center, spacing: 14) {
          VStack(alignment: .leading, spacing: 4) {
            totalAmount(size: size)
            Spacer(minLength: 0)
            statusRow()
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          VStack(alignment: .leading, spacing: 6) {
            breakdownRow("stocks", value: entry.snapshot?.stocks, color: .blue)
            breakdownRow("crypto", value: entry.snapshot?.crypto, color: .purple)
            breakdownRow("other", value: entry.snapshot?.other, color: .orange)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        totalAmount(size: size)
        if size == .large {
          Spacer(minLength: 0)
          HStack(alignment: .top, spacing: 10) {
            breakdownColumn("stocks", value: entry.snapshot?.stocks, color: .blue)
            breakdownColumn("crypto", value: entry.snapshot?.crypto, color: .purple)
            breakdownColumn("other", value: entry.snapshot?.other, color: .orange)
          }
        }
        Spacer(minLength: 0)
        statusRow()
      }
    }
    .padding(size == .small ? 14 : 16)

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
        .font(.system(size: 16, weight: .bold))
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
        .font(.system(size: size == .large ? 15 : 14, weight: .medium))
        .foregroundStyle(.secondary)
      Text(total)
        .font(.system(size: size == .small ? 29 : size == .medium ? 33 : 40,
                      weight: .bold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .privacySensitive()
    }
  }

  private func statusRow() -> some View {
    HStack(spacing: 5) {
      Circle().fill(statusColor).frame(width: 6, height: 6)
      Text(status)
      Spacer(minLength: 0)
      if let updateTime { Text(updateTime) }
    }
    .font(.system(size: 12, weight: .medium))
    .foregroundStyle(.secondary)
    .lineLimit(1)
    .minimumScaleFactor(0.85)
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

  private func breakdownColumn(_ key: String, value: String?, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 3) {
        Circle().fill(color).frame(width: 6, height: 6)
        Text(word(key)).lineLimit(1).minimumScaleFactor(0.85)
      }
      .font(.system(size: 14, weight: .medium))
      .foregroundStyle(.secondary)
      Text(isHidden ? "••••" : (value ?? "—"))
        .font(.system(size: 19, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .privacySensitive()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func breakdownRow(_ key: String, value: String?, color: Color) -> some View {
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 6, height: 6)
      Text(word(key))
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Spacer(minLength: 2)
      Text(isHidden ? "••••" : (value ?? "—"))
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .privacySensitive()
    }
  }
}

private struct AssetSummaryWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: AssetWidgetSnapshotStore.widgetKind, provider: AssetWidgetProvider()) {
      AssetWidgetView(entry: $0)
    }
    .configurationDisplayName("iAssets")
    .description(WidgetWords.text("description", WidgetWords.language(nil)))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                        .accessoryRectangular, .accessoryInline])
    .contentMarginsDisabled()
  }
}

@main
struct AssetsWidgetBundle: WidgetBundle {
  var body: some Widget { AssetSummaryWidget() }
}
