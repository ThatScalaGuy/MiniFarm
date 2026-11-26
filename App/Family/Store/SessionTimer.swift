import Foundation

/// Play timer with a soft end (doc 03 §6). Pure value type; the store feeds it elapsed time.
///
/// Flow: `running` → `tired` (last 2 minutes) → `windDown` (time is up, current action ends, evening ritual)
/// → `fallbackSleep` (no ritual finished after 3 minutes, soft good night overlay) → `finished`.
struct SessionTimer: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// No session or no time limit set.
        case off
        case running(remaining: TimeInterval)
        /// Pelle yawns. Prefer short, calm wishes.
        case tired(remaining: TimeInterval)
        /// Time is up. Let the child finish the current action, then start the evening ritual.
        case windDown(graceRemaining: TimeInterval)
        /// Family shows a soft good night overlay, then the session ends.
        case fallbackSleep(remaining: TimeInterval)
        case finished
    }

    static let tiredLead: TimeInterval = 120
    static let windDownGrace: TimeInterval = 180
    static let fallbackDuration: TimeInterval = 8
    /// Larger steps are clamped, so a long stall never ends a session at once.
    static let maxStep: TimeInterval = 5

    private(set) var limit: TimeInterval?
    private(set) var elapsed: TimeInterval = 0
    private(set) var windDownStartedAt: TimeInterval?
    private(set) var isActive = false

    init() {}

    var phase: Phase {
        guard isActive, let limit else { return .off }
        if let start = windDownStartedAt {
            let since = elapsed - start
            if since < Self.windDownGrace {
                return .windDown(graceRemaining: Self.windDownGrace - since)
            }
            if since < Self.windDownGrace + Self.fallbackDuration {
                return .fallbackSleep(remaining: Self.windDownGrace + Self.fallbackDuration - since)
            }
            return .finished
        }
        let remaining = max(limit - elapsed, 0)
        return remaining <= Self.tiredLead ? .tired(remaining: remaining) : .running(remaining: remaining)
    }

    mutating func start(limitMinutes: Int?) {
        self = SessionTimer()
        isActive = true
        limit = limitMinutes.map { TimeInterval($0) * 60 }
        markWindDownIfDue()
    }

    mutating func stop() {
        self = SessionTimer()
    }

    /// Changes the limit during a session. Time already played counts.
    mutating func setLimit(minutes: Int?) {
        limit = minutes.map { TimeInterval($0) * 60 }
        if limit.map({ elapsed < $0 }) ?? true {
            windDownStartedAt = nil
        }
        markWindDownIfDue()
    }

    mutating func advance(by seconds: TimeInterval) {
        guard isActive, seconds.isFinite else { return }
        elapsed += min(max(seconds, 0), Self.maxStep)
        markWindDownIfDue()
    }

    /// Jumps from the wind down to the good night overlay, for example when gameplay cannot run its ritual.
    mutating func skipToFallback() {
        guard isActive, let start = windDownStartedAt, elapsed - start < Self.windDownGrace else { return }
        windDownStartedAt = elapsed - Self.windDownGrace
    }

    private mutating func markWindDownIfDue() {
        guard isActive, let limit, windDownStartedAt == nil, elapsed >= limit else { return }
        windDownStartedAt = elapsed
    }
}
