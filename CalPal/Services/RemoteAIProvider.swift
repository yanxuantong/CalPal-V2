import Foundation

struct RemoteCalendarAIPolicy: Equatable {
    var isEnabled: Bool
    var endpoint: URL?
    var allowsCommandTextUpload: Bool

    static let localOnly = RemoteCalendarAIPolicy(isEnabled: false, endpoint: nil, allowsCommandTextUpload: false)

    static func explicitOptIn(endpoint: URL) -> RemoteCalendarAIPolicy {
        RemoteCalendarAIPolicy(isEnabled: true, endpoint: endpoint, allowsCommandTextUpload: true)
    }

    var canSendRequests: Bool {
        isEnabled && endpoint != nil && allowsCommandTextUpload
    }
}

struct ProductionPrivacyConfiguration: Equatable {
    var remoteAIPolicy: RemoteCalendarAIPolicy
    var allowsTelemetryExport: Bool

    static let appStoreLocalOnly = ProductionPrivacyConfiguration(
        remoteAIPolicy: .localOnly,
        allowsTelemetryExport: false
    )

    var keepsCommandTextOnDevice: Bool {
        !remoteAIPolicy.canSendRequests
    }

    var releaseSummary: String {
        if remoteAIPolicy.canSendRequests {
            return "Remote AI text upload is enabled; App Store privacy answers and user consent must match this build."
        }
        return "Remote AI text upload is disabled. Calendar commands stay on device."
    }

    var telemetrySummary: String {
        allowsTelemetryExport ? "Telemetry export is enabled." : "Telemetry export is disabled."
    }
}

struct RemoteCalendarAIRequest: Equatable, Codable {
    var commandText: String
    var localeIdentifier: String
    var timeZoneIdentifier: String
    var currentDate: Date
}

struct RemoteCalendarAIResponse: Equatable, Codable {
    var parsedCommand: ParsedCalendarCommand
}

protocol RemoteCalendarAIClientProtocol: AnyObject {
    func parse(_ request: RemoteCalendarAIRequest, endpoint: URL) async throws -> RemoteCalendarAIResponse
}

enum RemoteCalendarAIError: Error, Equatable {
    case disabled
    case missingEndpoint
}

final class RemoteCalendarAIParser: CalendarCommandParsing {
    private let fallback: CalendarCommandParsing
    private let client: RemoteCalendarAIClientProtocol
    private let policy: RemoteCalendarAIPolicy
    private let localeIdentifier: () -> String
    private let timeZone: TimeZone
    private let now: () -> Date

    init(
        fallback: CalendarCommandParsing,
        client: RemoteCalendarAIClientProtocol,
        policy: RemoteCalendarAIPolicy,
        localeIdentifier: @escaping () -> String = { Locale.current.identifier },
        timeZone: TimeZone = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.fallback = fallback
        self.client = client
        self.policy = policy
        self.localeIdentifier = localeIdentifier
        self.timeZone = timeZone
        self.now = now
    }

    func parseCommand(_ text: String) async -> ParsedCalendarCommand {
        guard policy.isEnabled else {
            return await fallback.parseCommand(text)
        }
        guard let endpoint = policy.endpoint, policy.allowsCommandTextUpload else {
            return await failedOverFallback(text)
        }

        do {
            let request = RemoteCalendarAIRequest(
                commandText: text,
                localeIdentifier: localeIdentifier(),
                timeZoneIdentifier: timeZone.identifier,
                currentDate: now()
            )
            let response = try await client.parse(request, endpoint: endpoint)
            return routed(response.parsedCommand, as: .remoteAIGenerated)
        } catch {
            return await failedOverFallback(text)
        }
    }

    private func failedOverFallback(_ text: String) async -> ParsedCalendarCommand {
        let parsed = await fallback.parseCommand(text)
        return routed(parsed, as: .remoteAIFailedOver)
    }

    private func routed(_ parsed: ParsedCalendarCommand, as route: CalendarParseRoute) -> ParsedCalendarCommand {
        var copy = parsed
        copy.parseRoute = route
        return copy
    }
}
