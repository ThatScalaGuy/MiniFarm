import SwiftUI
import UIKit

struct BasketTouchSurface: UIViewRepresentable {
    typealias Carry = BasketCarry<ObjectIdentifier>
    var receive: (Carry.Phase, ObjectIdentifier, CGPoint, CGFloat, CGSize) -> Void

    func makeUIView(context: Context) -> Contacts {
        let view = Contacts()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.receive = receive
        return view
    }

    func updateUIView(_ view: Contacts, context: Context) { view.receive = receive }

    final class Contacts: UIView {
        var receive: ((Carry.Phase, ObjectIdentifier, CGPoint, CGFloat, CGSize) -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { send(.began, touches) }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { send(.moved, touches) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { send(.ended, touches) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { send(.cancelled, touches) }

        private func send(_ phase: Carry.Phase, _ touches: Set<UITouch>) {
            for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) where touch.type == .direct {
                #if targetEnvironment(simulator)
                // No contact-area sensor. The A16 simulator reports 31.9 pt even for one synthetic fingertip.
                let radius: CGFloat = 0
                #else
                let radius = max(0, touch.majorRadius - touch.majorRadiusTolerance)
                #endif
                receive?(phase, ObjectIdentifier(touch), touch.location(in: self), radius, bounds.size)
            }
        }
    }
}
