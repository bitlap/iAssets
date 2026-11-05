import Flutter
import UIKit
import XCTest
import StoreKit
@testable import Runner

class RunnerTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  func testLegacyCutoffIsStrictAndProductionOnly() {
    for offset in [-1.0, 0, 1] {
      XCTAssertEqual(ProEntitlementPolicy.grantsLegacy(
        bundleID: "org.bitlap.assets", expectedBundleID: "org.bitlap.assets",
        environment: .production, originalPurchaseDate: now.addingTimeInterval(offset),
        cutoff: now), offset < 0)
    }
    XCTAssertFalse(ProEntitlementPolicy.grantsLegacy(
      bundleID: "org.bitlap.assets", expectedBundleID: "org.bitlap.assets",
      environment: .sandbox, originalPurchaseDate: .distantPast, cutoff: now))
    XCTAssertFalse(ProEntitlementPolicy.grantsLegacy(
      bundleID: "other.app", expectedBundleID: "org.bitlap.assets",
      environment: .production, originalPurchaseDate: .distantPast, cutoff: now))
    XCTAssertFalse(ProEntitlementPolicy.grantsLegacy(
      bundleID: "org.bitlap.assets", expectedBundleID: "org.bitlap.assets",
      environment: .production, originalPurchaseDate: .distantPast, cutoff: nil))
  }

  func testLifetimeRequiresCorrectIDTypeAndNoRevocation() {
    XCTAssertTrue(ProEntitlementPolicy.grantsLifetime(
      productID: ProEntitlementPolicy.lifetime, productType: .nonConsumable,
      revoked: false, upgraded: false))
    for id in [ProEntitlementPolicy.monthly, ProEntitlementPolicy.yearly, "unrelated"] {
      XCTAssertFalse(ProEntitlementPolicy.grantsLifetime(
        productID: id, productType: .nonConsumable, revoked: false, upgraded: false))
    }
    for type in [Product.ProductType.autoRenewable, .consumable] {
      XCTAssertFalse(ProEntitlementPolicy.grantsLifetime(
        productID: ProEntitlementPolicy.lifetime, productType: type,
        revoked: false, upgraded: false))
    }
    for flags in [(true, false), (false, true)] {
      XCTAssertFalse(ProEntitlementPolicy.grantsLifetime(
        productID: ProEntitlementPolicy.lifetime, productType: .nonConsumable,
        revoked: flags.0, upgraded: flags.1))
    }
  }

  func testBothSubscriptionsRequireFutureExpiry() {
    for id in [ProEntitlementPolicy.monthly, ProEntitlementPolicy.yearly] {
      for offset in [-1.0, 0, 1] {
        let expiry = now.addingTimeInterval(offset)
        XCTAssertEqual(ProEntitlementPolicy.subscriptionExpiry(
          productID: id, productType: .autoRenewable, revoked: false,
          upgraded: false, expiration: expiry, now: now), offset > 0 ? expiry : nil)
      }
      XCTAssertNil(ProEntitlementPolicy.subscriptionExpiry(
        productID: id, productType: .autoRenewable, revoked: false,
        upgraded: false, expiration: nil, now: now))
    }
  }

  func testRevokedUpgradedOrMismatchedSubscriptionsCannotUnlock() {
    for id in [ProEntitlementPolicy.lifetime, "unrelated"] {
      XCTAssertNil(ProEntitlementPolicy.subscriptionExpiry(
        productID: id, productType: .autoRenewable, revoked: false,
        upgraded: false, expiration: .distantFuture, now: now))
    }
    for flags in [(true, false), (false, true)] {
      XCTAssertNil(ProEntitlementPolicy.subscriptionExpiry(
        productID: ProEntitlementPolicy.monthly, productType: .autoRenewable,
        revoked: flags.0, upgraded: flags.1, expiration: .distantFuture, now: now))
    }
    XCTAssertNil(ProEntitlementPolicy.subscriptionExpiry(
      productID: ProEntitlementPolicy.monthly, productType: .nonConsumable,
      revoked: false, upgraded: false, expiration: .distantFuture, now: now))
  }

  func testGracePeriodUsesItsOwnDeadline() {
    let expiredBillingPeriod = now.addingTimeInterval(-60)
    let graceDeadline = now.addingTimeInterval(60)
    XCTAssertNil(ProEntitlementPolicy.subscriptionExpiry(
      productID: ProEntitlementPolicy.yearly, productType: .autoRenewable,
      revoked: false, upgraded: false, expiration: expiredBillingPeriod, now: now))
    XCTAssertEqual(ProEntitlementPolicy.subscriptionExpiry(
      productID: ProEntitlementPolicy.yearly, productType: .autoRenewable,
      revoked: false, upgraded: false, expiration: graceDeadline, now: now), graceDeadline)
    XCTAssertNil(ProEntitlementPolicy.subscriptionExpiry(
      productID: ProEntitlementPolicy.yearly, productType: .autoRenewable,
      revoked: false, upgraded: false, expiration: graceDeadline, now: graceDeadline))
  }

  func testPermanentEntitlementsTakePriorityOverSubscription() {
    XCTAssertEqual(ProEntitlementPolicy.kind(
      legacy: true, lifetime: true, expiry: .distantFuture, now: now), "legacy")
    XCTAssertEqual(ProEntitlementPolicy.kind(
      legacy: false, lifetime: true, expiry: .distantFuture, now: now), "lifetime")
    XCTAssertEqual(ProEntitlementPolicy.kind(
      legacy: false, lifetime: false, expiry: .distantFuture, now: now), "subscription")
    for expiry in [nil, now, now.addingTimeInterval(-1)] {
      XCTAssertEqual(ProEntitlementPolicy.kind(
        legacy: false, lifetime: false, expiry: expiry, now: now), "free")
    }
  }

  func testWidgetPrivacyFlagIsSharedAndSnapshotRedactsEveryAmount() {
    let key = AssetWidgetSnapshotStore.hideAmountsKey
    let local = UserDefaults.standard
    let shared = UserDefaults(suiteName: AssetWidgetSnapshotStore.group)
    let oldLocal = local.object(forKey: key)
    let oldShared = shared?.object(forKey: key)
    defer {
      if let oldLocal { local.set(oldLocal, forKey: key) }
      else { local.removeObject(forKey: key) }
      if let oldShared { shared?.set(oldShared, forKey: key) }
      else { shared?.removeObject(forKey: key) }
    }

    AssetWidgetSnapshotStore.setPrivacyPreference(key, value: true)
    XCTAssertTrue(local.bool(forKey: key))
    XCTAssertTrue(shared?.bool(forKey: key) ?? false)
    XCTAssertTrue(AssetWidgetSnapshotStore.privacyIsEnabled)

    let snapshot = AssetWidgetSnapshot(
      schema: 1, currency: "USD", language: "zh", updatedAtMillis: 1,
      incomplete: false, hidden: false, total: "$100", stocks: "$40",
      crypto: "$30", other: "$30")
    let protected = AssetWidgetSnapshotStore.protectedSnapshot(snapshot, privacyEnabled: true)
    XCTAssertTrue(protected.hidden)
    XCTAssertNil(protected.total)
    XCTAssertNil(protected.stocks)
    XCTAssertNil(protected.crypto)
    XCTAssertNil(protected.other)
  }

}
