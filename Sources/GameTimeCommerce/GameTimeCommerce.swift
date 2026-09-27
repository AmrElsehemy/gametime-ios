import Foundation
import GameTimeCore
import GameTimeServices

public struct RewardOffer: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: String
    public let amount: Int

    public init(id: String, kind: String, amount: Int = 1) {
        self.id = id
        self.kind = kind
        self.amount = amount
    }
}

public struct RewardRequest: Codable, Equatable, Sendable, Identifiable {
    /// The exactly-once key. It must identify the reward opportunity, not the
    /// tap: a fresh value per retry lets every retry grant again.
    public let id: String
    public let offer: RewardOffer

    public init(id: String, offer: RewardOffer) {
        self.id = id
        self.offer = offer
    }

    /// Derives a stable id from the offer and the opportunity it rewards,
    /// e.g. `"level:v1-006:attempt:3"`.
    public init(offer: RewardOffer, opportunity: String) {
        self.init(id: "\(offer.id):\(opportunity)", offer: offer)
    }
}

public struct RewardTransaction: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let rewardID: String
    public let offerID: String
    public let grantedAt: Date

    public init(
        id: UUID = UUID(),
        rewardID: String,
        offerID: String,
        grantedAt: Date
    ) {
        self.id = id
        self.rewardID = rewardID
        self.offerID = offerID
        self.grantedAt = grantedAt
    }
}

public enum RewardedAdOutcome: Equatable, Sendable {
    case inProgress
    case unavailable
    case notEarned
    case alreadyGranted
    case granted(RewardTransaction)
}

public protocol RewardedAdProviding: Sendable {
    func isAvailable(for offer: RewardOffer) async -> Bool
    func present(offer: RewardOffer) async throws -> Bool
}

public protocol RewardReceiptPersisting: Sendable {
    func contains(rewardID: String) async -> Bool
    func transaction(for rewardID: String) async -> RewardTransaction?
    func record(_ transaction: RewardTransaction) async throws -> Bool
}

public actor InMemoryRewardReceiptStore: RewardReceiptPersisting {
    private var transactionsByRewardID: [String: RewardTransaction]

    public init(transactions: [RewardTransaction] = []) {
        // Seeds come from persisted data; keep the earliest grant for a
        // duplicated reward id instead of trapping at launch.
        self.transactionsByRewardID = Dictionary(
            transactions.map { ($0.rewardID, $0) },
            uniquingKeysWith: { $0.grantedAt <= $1.grantedAt ? $0 : $1 }
        )
    }

    public func contains(rewardID: String) async -> Bool {
        transactionsByRewardID[rewardID] != nil
    }

    public func transaction(for rewardID: String) async -> RewardTransaction? {
        transactionsByRewardID[rewardID]
    }

    public func record(_ transaction: RewardTransaction) async throws -> Bool {
        guard transactionsByRewardID[transaction.rewardID] == nil else {
            return false
        }
        transactionsByRewardID[transaction.rewardID] = transaction
        return true
    }

    public func transactions() async -> [RewardTransaction] {
        transactionsByRewardID.values.sorted {
            $0.grantedAt < $1.grantedAt
        }
    }
}

/// Serializes rewarded-ad attempts so the same deterministic reward identifier
/// cannot be granted twice even when callbacks or UI actions race.
public actor RewardedAdCoordinator {
    private let provider: any RewardedAdProviding
    private let receipts: RewardReceiptLedger
    private var presenting = false
    private let now: @Sendable () -> Date

    public init(
        provider: any RewardedAdProviding,
        receipts: any RewardReceiptPersisting,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.receipts = RewardReceiptLedger(store: receipts)
        self.now = now
    }

    /// The transaction behind an earlier `.granted`/`.alreadyGranted`, so a
    /// caller that crashed before applying a reward can apply it on relaunch.
    public func grantedTransaction(for rewardID: String) async -> RewardTransaction? {
        await receipts.transaction(for: rewardID)
    }

    /// Provider errors propagate; receipt-store errors after an earned ad do
    /// not, because the player already watched the ad.
    public func attempt(_ request: RewardRequest) async throws -> RewardedAdOutcome {
        guard !presenting else { return .inProgress }
        presenting = true
        defer { presenting = false }
        if await receipts.contains(rewardID: request.id) {
            return .alreadyGranted
        }

        guard await provider.isAvailable(for: request.offer) else {
            return .unavailable
        }

        guard try await provider.present(offer: request.offer) else {
            return .notEarned
        }

        let transaction = RewardTransaction(
            rewardID: request.id,
            offerID: request.offer.id,
            grantedAt: now()
        )

        guard await receipts.record(transaction) else {
            return .alreadyGranted
        }

        return .granted(transaction)
    }
}

/// Wraps a receipt store so an earned reward is never dropped by a failing
/// write: the grant is held in memory, counts as granted for this session and
/// is written on the next attempt.
actor RewardReceiptLedger {
    private let store: any RewardReceiptPersisting
    private var unpersisted: [String: RewardTransaction] = [:]

    init(store: any RewardReceiptPersisting) {
        self.store = store
    }

    func contains(rewardID: String) async -> Bool {
        await flush()
        if unpersisted[rewardID] != nil { return true }
        return await store.contains(rewardID: rewardID)
    }

    func transaction(for rewardID: String) async -> RewardTransaction? {
        if let pending = unpersisted[rewardID] { return pending }
        return await store.transaction(for: rewardID)
    }

    /// Returns false only when the store already holds this reward id.
    func record(_ transaction: RewardTransaction) async -> Bool {
        do {
            return try await store.record(transaction)
        } catch {
            unpersisted[transaction.rewardID] = transaction
            return true
        }
    }

    private func flush() async {
        for (rewardID, transaction) in unpersisted {
            if (try? await store.record(transaction)) != nil {
                unpersisted[rewardID] = nil
            }
        }
    }
}

public protocol EntitlementProviding: Sendable {
    func hasEntitlement(_ productID: String) async -> Bool
    func restorePurchases() async throws
}
