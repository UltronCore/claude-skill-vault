---
name: storekit-iap
description: >
  StoreKit 2 in-app purchases and subscriptions: loading products, purchasing,
  validating entitlements, and listening for transaction updates.
  Triggers on: StoreKit, IAP, in-app purchase, subscription, Product.products,
  Transaction, entitlement, consumable, non-consumable, auto-renewable.
---

# StoreKit 2 In-App Purchases

## When to Use
- Adding any purchasable content: consumable coins, non-consumable unlocks, or auto-renewable subscriptions
- Checking whether a user has an active entitlement before showing gated content
- Handling restored purchases or subscription renewals
- Writing StoreKit config files for local testing

## Core Rules
1. Always call `Transaction.updates` listener at app launch — missing it means missed purchases (e.g., renewals processed in background).
2. Always `finish()` a transaction after delivering content — unfin­ished transactions reappear every launch.
3. Never cache entitlement state in UserDefaults as source of truth; re-check `Transaction.currentEntitlements` on foreground.
4. Use `Product.SubscriptionInfo.status` for subscription state; `isExpired`, `isInBillingRetry`, and `willAutoRenew` are all distinct states.
5. Server-side receipt validation (App Store Server API) is required for any backend-gated content; JWS transactions from StoreKit 2 are self-verifiable without a receipt.
6. For consumables, track fulfillment yourself — StoreKit only confirms purchase, not delivery.
7. Test each flow with a StoreKit config file (`.storekit`) before ever touching sandbox — much faster iteration.
8. Present `Product.PurchaseError.userCancelled` silently; only surface errors that require user action.
9. For family sharing, check `Transaction.ownershipType == .familyShared`.
10. In iOS 17+ prefer `PaywallView` or custom `ProductView` over building purchase UI from scratch.

## Product Loading

```swift
import StoreKit

// Product IDs defined in App Store Connect and mirrored in your .storekit config
enum ProductID {
    static let chapterUnlock = "com.mangareader.chapter.unlock"    // non-consumable
    static let coinPack100   = "com.mangareader.coins.100"         // consumable
    static let proMonthly    = "com.mangareader.pro.monthly"       // auto-renewable
    static let proAnnual     = "com.mangareader.pro.annual"
    
    static var all: [String] { [chapterUnlock, coinPack100, proMonthly, proAnnual] }
}

@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactionUpdates()
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }
    
    deinit { updateListenerTask?.cancel() }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
}
```

## Purchase Flow

```swift
extension StoreManager {
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await deliverContent(for: transaction)
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            // Ask Mom to approve — show "awaiting approval" UI
            return false
            
        @unknown default:
            return false
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error         // JWS signature invalid — do not deliver
        case .verified(let value):
            return value
        }
    }
    
    private func deliverContent(for transaction: Transaction) async {
        switch transaction.productType {
        case .consumable:
            // Add coins to local store, persist to your own DB
            await addCoins(100)
        case .nonConsumable:
            purchasedProductIDs.insert(transaction.productID)
        case .autoRenewable:
            purchasedProductIDs.insert(transaction.productID)
        default:
            break
        }
    }
}
```

## Transaction Updates Listener (CRITICAL)

```swift
extension StoreManager {
    // Must start at app launch — catches purchases made outside the app
    // (renewals, Ask-to-Buy approvals, purchases on another device)
    func listenForTransactionUpdates() -> Task<Void, Error> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.deliverContent(for: transaction)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
}
```

## Checking Current Entitlements

```swift
extension StoreManager {
    // Call on app foreground, not just launch
    func refreshEntitlements() async {
        var validIDs = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            
            // currentEntitlements only returns non-expired, non-revoked purchases
            if transaction.revocationDate == nil {
                validIDs.insert(transaction.productID)
            }
        }
        
        await MainActor.run { self.purchasedProductIDs = validIDs }
    }
    
    var isPro: Bool {
        purchasedProductIDs.contains(ProductID.proMonthly) ||
        purchasedProductIDs.contains(ProductID.proAnnual)
    }
}
```

## Subscription Status Details

```swift
func checkSubscriptionStatus() async {
    guard let product = products.first(where: { $0.id == ProductID.proMonthly }),
          let statuses = try? await product.subscription?.status else { return }
    
    for status in statuses {
        switch status.state {
        case .subscribed:
            print("Active subscriber")
        case .expired:
            print("Expired — offer win-back")
        case .inBillingRetryPeriod:
            print("Payment failed, Apple retrying — still has access per policy")
        case .inGracePeriod:
            print("Grace period — maintain access, prompt to update payment")
        case .revoked:
            print("Refunded — revoke access immediately")
        @unknown default:
            break
        }
        
        // Check renewal intent
        if let renewal = try? status.renewalInfo.payloadValue {
            print("Will auto-renew: \(renewal.willAutoRenew)")
            print("Product changing to: \(renewal.autoRenewProductID ?? "none")")
        }
    }
}
```

## StoreKit Config File (Testing)

Create `Subscriptions.storekit` in Xcode:
- File > New > File > StoreKit Config File
- Add products matching your App Store Connect IDs exactly
- In scheme: Run > Options > StoreKit Config → select the file
- Use `StoreKitTestSession` in unit tests for deterministic purchase flows

```swift
// In XCTest — control time, approve purchases, trigger renewals
import StoreKitTest

class PurchaseTests: XCTestCase {
    var session: SKTestSession!
    
    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Subscriptions")
        session.disableDialogs = true
        session.clearTransactions()
    }
    
    func testSubscriptionPurchase() async throws {
        try await session.buyProduct(productIdentifier: ProductID.proMonthly)
        // advance time to trigger renewal
        try session.forceRenewalOfSubscription(productIdentifier: ProductID.proMonthly)
    }
}
```

## Common Patterns

### Gating UI on Entitlement
```swift
struct ChapterView: View {
    @EnvironmentObject var store: StoreManager
    let chapter: Chapter
    
    var body: some View {
        if chapter.isFree || store.isPro || store.purchasedProductIDs.contains(chapter.productID) {
            ChapterReaderView(chapter: chapter)
        } else {
            PaywallView(chapter: chapter)
        }
    }
}
```

### Restore Purchases Button
```swift
Button("Restore Purchases") {
    Task {
        // StoreKit 2: just re-check currentEntitlements after syncing
        try? await AppStore.sync()
        await store.refreshEntitlements()
    }
}
```

### Subscription Price Localization
```swift
// Always use StoreKit's formatted price — never hardcode "$4.99"
Text(product.displayPrice)                         // "$4.99"
Text(product.subscription?.subscriptionPeriod.debugDescription ?? "")

// For "per month" formatting:
if let sub = product.subscription {
    let unit = sub.subscriptionPeriod.unit  // .month, .year, .week, .day
    let value = sub.subscriptionPeriod.value
}
```

## Decision Table: Product Types

| Type | `finish()` required | Survives reinstall | Use case |
|------|--------------------|--------------------|----------|
| Consumable | Yes | No | Coins, boosts |
| Non-consumable | Yes | Yes (restore) | Chapter unlock, theme |
| Auto-renewable | Yes | Yes (entitlement) | Pro subscription |
| Non-renewing | Yes | No (manual restore) | Season pass |

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ios-swift/storekit-iap/.gitnexus
Last indexed: 2026-05-23
