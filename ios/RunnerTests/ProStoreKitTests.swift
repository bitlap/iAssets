import Flutter
import StoreKit
import StoreKitTest
import XCTest
@testable import Runner

/// Exercises the production StoreKit adapter against Apple's local test store.
/// No Apple account, App Store server, or real payment is involved.
final class ProStoreKitTests: XCTestCase {
  @MainActor
  private func withStore(_ body: (SKTestSession, ProStore) async throws -> Void) async throws {
    let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Pro", withExtension: "storekit"))
    let session = try SKTestSession(contentsOf: url)
    session.resetToDefaultState()
    session.disableDialogs = true
    session.clearTransactions()
    defer {
      session.clearTransactions()
      session.resetToDefaultState()
    }
    let products = try await Product.products(for: ProEntitlementPolicy.ids)
    guard Set(products.map(\.id)) == ProEntitlementPolicy.ids else {
      XCTFail("Local StoreKit catalog is unavailable; run the ProStoreKit scheme with its test plan")
      return
    }
    let store = ProStore()
    _ = try await waitForKind(store, "free")
    try await body(session, store)
  }

  @MainActor
  private func call(_ store: ProStore, _ method: String, _ args: [String: Any]? = nil) async throws -> Any? {
    var response: Any?
    await store.handle(FlutterMethodCall(methodName: method, arguments: args)) { response = $0 }
    if let error = response as? FlutterError {
      throw NSError(domain: "ProStoreKitTests", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "\(error.code): \(error.message ?? "")"])
    }
    return response
  }

  @MainActor
  private func status(_ store: ProStore) async throws -> [String: Any] {
    let response = try await call(store, "status", ["legacyCutoff": "2026-11-01T00:00:00Z"])
    return try XCTUnwrap(response as? [String: Any])
  }

  @MainActor
  private func waitForKind(_ store: ProStore, _ expected: String) async throws -> [String: Any] {
    // StoreKit mutations return before the entitlement stream catches up.
    for _ in 0..<50 {
      let value = try await status(store)
      if value["kind"] as? String == expected { return value }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    XCTFail("StoreKit entitlement did not become \(expected) within the bounded wait")
    return try await status(store)
  }

  @MainActor
  func testCatalogLoadsAllThreeRealStoreKitProductsWithoutGrantingLegacy() async throws {
    try await withStore { _, store in
      let value = try await self.status(store)
      let products = try XCTUnwrap(value["products"] as? [[String: String]])
      XCTAssertEqual(Set(products.compactMap { $0["id"] }), ProEntitlementPolicy.ids)
      XCTAssertTrue(products.allSatisfy { !($0["price"] ?? "").isEmpty })
      XCTAssertEqual(value["kind"] as? String, "free")
      XCTAssertEqual(value["legacyVerified"] as? Bool, true)
    }
  }

  @MainActor
  func testLifetimePurchaseRestoreDuplicateProtectionAndRefund() async throws {
    try await withStore { session, store in
      _ = try await self.status(store)
      let result = try await self.call(store, "purchase", ["id": ProEntitlementPolicy.lifetime])
      XCTAssertEqual(result as? String, "success")
      let purchased = try await self.status(store)
      XCTAssertEqual(purchased["kind"] as? String, "lifetime")
      let duplicate = try await self.call(store, "purchase", ["id": ProEntitlementPolicy.lifetime])
      XCTAssertEqual(duplicate as? String, "owned")
      XCTAssertEqual(session.allTransactions().count, 1)
      _ = try await self.call(store, "restore")
      let restored = try await self.status(ProStore())
      XCTAssertEqual(restored["kind"] as? String, "lifetime")
      let transaction = try XCTUnwrap(session.allTransactions().first)
      try session.refundTransaction(identifier: transaction.identifier)
      let refunded = try await self.waitForKind(store, "free")
      XCTAssertEqual(refunded["kind"] as? String, "free")
    }
  }

  @MainActor
  func testMonthlyAndYearlyPurchaseRenewalAndExpiration() async throws {
    for id in [ProEntitlementPolicy.monthly, ProEntitlementPolicy.yearly] {
      try await withStore { session, store in
        _ = try await self.status(store)
        let result = try await self.call(store, "purchase", ["id": id])
        XCTAssertEqual(result as? String, "success")
        let purchased = try await self.status(store)
        XCTAssertEqual(purchased["kind"] as? String, "subscription")
        XCTAssertNotNil(purchased["expiresAt"])
        let duplicate = try await self.call(store, "purchase", ["id": id])
        XCTAssertEqual(duplicate as? String, "owned")
        try session.forceRenewalOfSubscription(productIdentifier: id)
        let renewed = try await self.status(store)
        XCTAssertEqual(renewed["kind"] as? String, "subscription")
        try session.expireSubscription(productIdentifier: id)
        let expired = try await self.waitForKind(store, "free")
        XCTAssertEqual(expired["kind"] as? String, "free")
      }
    }
  }

  @MainActor
  func testAskToBuyDoesNotUnlockUntilApproved() async throws {
    try await withStore { session, store in
      _ = try await self.status(store)
      session.askToBuyEnabled = true
      let result = try await self.call(store, "purchase", ["id": ProEntitlementPolicy.lifetime])
      XCTAssertEqual(result as? String, "pending")
      let pending = try await self.status(store)
      XCTAssertEqual(pending["kind"] as? String, "free")
      let transaction = try XCTUnwrap(session.allTransactions().first)
      try session.approveAskToBuyTransaction(identifier: transaction.identifier)
      let approved = try await self.waitForKind(store, "lifetime")
      XCTAssertEqual(approved["kind"] as? String, "lifetime")
    }
  }
}
