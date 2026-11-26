import Foundation

/// Written puzzle that adults solve easily and young children cannot read (doc 11 §8).
struct GatePuzzle: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Number written as a German word, typed on a keypad.
        case numberWord
        /// Pick the sum of two numbers from four choices. Used while VoiceOver runs.
        case sumChoice
    }

    let kind: Kind
    /// Text shown on screen. Never spoken by the game.
    let prompt: String
    let answer: Int
    /// Four options for `sumChoice`, empty for `numberWord`.
    let choices: [Int]

    static func numberWord<R: RandomNumberGenerator>(using generator: inout R) -> GatePuzzle {
        let value = Int.random(in: 21...99, using: &generator)
        return GatePuzzle(
            kind: .numberWord,
            prompt: "Tippe diese Zahl ein: \(GermanNumberWords.word(for: value))",
            answer: value,
            choices: []
        )
    }

    static func sumChoice<R: RandomNumberGenerator>(using generator: inout R) -> GatePuzzle {
        let first = Int.random(in: 12...49, using: &generator)
        let second = Int.random(in: 12...49, using: &generator)
        let answer = first + second
        var options: Set = [answer]
        while options.count < 4 {
            let offset = Int.random(in: 1...9, using: &generator) * (Bool.random(using: &generator) ? 1 : -1)
            options.insert(answer + offset)
        }
        return GatePuzzle(
            kind: .sumChoice,
            prompt: "Wähle die Summe von \(first) plus \(second).",
            answer: answer,
            choices: Array(options).shuffled(using: &generator)
        )
    }
}

enum GermanNumberWords {
    private static let units = ["", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun"]
    private static let teens = [
        "zehn", "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn",
    ]
    private static let tens = ["", "", "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig"]

    /// German word for 1...99, for example 47 gives "siebenundvierzig".
    static func word(for value: Int) -> String {
        precondition((1...99).contains(value))
        switch value {
        case 1...9:
            return units[value]
        case 10...19:
            return teens[value - 10]
        default:
            let unit = value % 10
            let ten = tens[value / 10]
            guard unit > 0 else { return ten }
            let unitWord = unit == 1 ? "ein" : units[unit]
            return unitWord + "und" + ten
        }
    }
}

/// Attempts and lockout of the parental gate. Kept in the store, so cancelling cannot skip a lockout.
struct ParentalGateState: Equatable, Sendable {
    static let maxFailures = 3
    static let lockout: TimeInterval = 30

    enum Result: Equatable, Sendable {
        case unlocked
        case wrong(attemptsLeft: Int)
        case locked(until: Date)
    }

    private(set) var puzzle: GatePuzzle
    private(set) var failures = 0
    private(set) var lockedUntil: Date?

    init(puzzle: GatePuzzle) {
        self.puzzle = puzzle
    }

    func isLocked(at now: Date) -> Bool {
        guard let lockedUntil else { return false }
        return now < lockedUntil
    }

    /// Checks an answer. A wrong answer always brings a new puzzle.
    mutating func submit(_ answer: Int, now: Date, nextPuzzle: () -> GatePuzzle) -> Result {
        if let lockedUntil, now < lockedUntil {
            return .locked(until: lockedUntil)
        }
        if lockedUntil != nil {
            lockedUntil = nil
            failures = 0
        }
        if answer == puzzle.answer {
            failures = 0
            puzzle = nextPuzzle()
            return .unlocked
        }
        failures += 1
        puzzle = nextPuzzle()
        if failures >= Self.maxFailures {
            let until = now.addingTimeInterval(Self.lockout)
            lockedUntil = until
            return .locked(until: until)
        }
        return .wrong(attemptsLeft: Self.maxFailures - failures)
    }

    /// Swaps the puzzle, for example when VoiceOver turns on. Keeps failures and lockout.
    mutating func replacePuzzle(_ newPuzzle: GatePuzzle) {
        puzzle = newPuzzle
    }
}

/// Small seeded generator, so tests get stable puzzles.
struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
