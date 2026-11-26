import SwiftUI

struct FarmRootView: View {
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.92, blue: 0.80).ignoresSafeArea()
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 88, weight: .medium, design: .rounded))
                .foregroundStyle(.orange)
                .accessibilityLabel("MiniFarm")
                .accessibilityIdentifier("farm.opening")
        }
    }
}
