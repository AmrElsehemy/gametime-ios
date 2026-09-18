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

public struct RewardTransaction: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let offerID: String
    public let grantedAt: Date

    public init(id: UUID = UUID(), offerID: String, grantedAt: Date) {
        self.id = id
        self.offerID = offerID
        self.grantedAt = grantedAt
    }
}

public protocol RewardedAdProviding: Sendable {
    func isAvailable(for offer: RewardOffer) async -> Bool
    func present(offer: RewardOffer) async throws -> Bool
}

public protocol EntitlementProviding: Sendable {
    func hasEntitlement(_ productID: String) async -> Bool
    func restorePurchases() async throws
}
