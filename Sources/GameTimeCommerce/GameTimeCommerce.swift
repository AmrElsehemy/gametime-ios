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
    public let id: String
    public let offer: RewardOffer

    public init(id: String, offer: RewardOffer) {
        self.id = id
        self.offer = offer
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
    func record(_ transaction: RewardTransaction) async throws -> Bool
}

public actor InMemoryRewardReceiptStore: RewardReceiptPersisting {
    private var transactionsByRewardID: [String: RewardTransaction]

    public init(transactions: [RewardTransaction] = []) {
        self.transactionsByRewardID = Dictionary(
            uniqueKeysWithValues: transactions.map { ($0.rewardID, $0) }
        )
    }

    public func contains(rewardID: String) async -> Bool {
        transactionsByRewardID[rewardID] != nil
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
    private let receipts: any RewardReceiptPersisting
    private let now: @Sendable () -> Date

    public init(
        provider: any RewardedAdProviding,
        receipts: any RewardReceiptPersisting,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.receipts = receipts
        self.now = now
    }

    public func attempt(_ request: RewardRequest) async throws -> RewardedAdOutcome {
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

        guard try await receipts.record(transaction) else {
            return .alreadyGranted
        }

        return .granted(transaction)
    }
}

public protocol EntitlementProviding: Sendable {
    func hasEntitlement(_ productID: String) async -> Bool
    func restorePurchases() async throws
}
