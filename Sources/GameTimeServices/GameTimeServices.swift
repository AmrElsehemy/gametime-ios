import Foundation
import GameTimeCore

public struct AnalyticsEvent: Equatable, Sendable {
    public let name: String
    public let properties: [String: String]

    public init(name: String, properties: [String: String] = [:]) {
        self.name = name
        self.properties = properties
    }
}

public protocol AnalyticsClient: Sendable {
    func track(_ event: AnalyticsEvent)
}

public protocol DiagnosticsClient: Sendable {
    func breadcrumb(_ message: String, metadata: [String: String])
    func record(error: Error, metadata: [String: String])
}

public protocol RemoteConfigProvider: Sendable {
    func boolValue(for key: String, default defaultValue: Bool) async -> Bool
    func stringValue(for key: String, default defaultValue: String) async -> String
}

public struct NoOpAnalyticsClient: AnalyticsClient {
    public init() {}
    public func track(_ event: AnalyticsEvent) {}
}

public struct NoOpDiagnosticsClient: DiagnosticsClient {
    public init() {}
    public func breadcrumb(_ message: String, metadata: [String: String] = [:]) {}
    public func record(error: Error, metadata: [String: String] = [:]) {}
}
