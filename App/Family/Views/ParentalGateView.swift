import SwiftUI

/// Written parental gate. No voice, no hints that a child could follow (doc 11 §8).
struct ParentalGateView: View {
    let store: FamilyStore

    @State private var input = ""
    @State private var feedback: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(spacing: 20) {
                header
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    if let remaining = store.gateLockRemaining() {
                        lockout(remaining: remaining)
                    } else {
                        puzzle
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("family.gate")
        .accessibilityAddTraits(.isModal)
        .onChange(of: store.gate.puzzle) { _, _ in input = "" }
    }

    private var header: some View {
        HStack {
            Text("Für Erwachsene")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                store.cancelGate()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zurück zum Spiel")
            .accessibilityIdentifier("family.gate.cancel")
        }
    }

    private func lockout(remaining: TimeInterval) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 44))
                .accessibilityHidden(true)
            Text("Zu viele falsche Antworten. Bitte in \(Int(remaining.rounded(.up))) Sekunden noch einmal versuchen.")
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("family.gate.lockout")
    }

    @ViewBuilder
    private var puzzle: some View {
        let puzzle = store.gate.puzzle
        VStack(spacing: 16) {
            Text(puzzle.prompt)
                .font(.title3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("family.gate.prompt")
            if let feedback {
                Text(feedback)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("family.gate.feedback")
            }
            switch puzzle.kind {
            case .numberWord:
                keypad
            case .sumChoice:
                choices(puzzle.choices)
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: 12) {
            Text(input.isEmpty ? " " : input)
                .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(input.isEmpty ? "Noch keine Eingabe" : "Eingabe \(input)")
                .accessibilityIdentifier("family.gate.input")
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { digit in
                            digitKey(digit)
                        }
                    }
                }
                GridRow {
                    Button {
                        if !input.isEmpty { input.removeLast() }
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Löschen")
                    .accessibilityIdentifier("family.gate.key.delete")
                    digitKey(0)
                    Button {
                        submit()
                    } label: {
                        Text("OK")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.isEmpty)
                    .accessibilityLabel("Bestätigen")
                    .accessibilityIdentifier("family.gate.submit")
                }
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        Button {
            guard input.count < 2 else { return }
            input.append(String(digit))
        } label: {
            Text("\(digit)")
                .font(.title2.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("family.gate.key.\(digit)")
    }

    private func choices(_ options: [Int]) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach([0, 2], id: \.self) { start in
                GridRow {
                    ForEach(Array(options.enumerated()).filter { $0.offset / 2 == start / 2 }, id: \.offset) { index, value in
                        Button {
                            check(value)
                        } label: {
                            Text("\(value)")
                                .font(.title2.weight(.semibold).monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("family.gate.choice.\(index)")
                    }
                }
            }
        }
    }

    private func submit() {
        guard let value = Int(input) else { return }
        check(value)
    }

    private func check(_ value: Int) {
        input = ""
        switch store.submitGate(answer: value) {
        case .unlocked:
            feedback = nil
        case .wrong(let attemptsLeft):
            feedback = "Das war nicht richtig. Hier ist eine neue Aufgabe. Noch \(attemptsLeft) \(attemptsLeft == 1 ? "Versuch" : "Versuche")."
        case .locked:
            feedback = nil
        }
    }
}
