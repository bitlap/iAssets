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

}
