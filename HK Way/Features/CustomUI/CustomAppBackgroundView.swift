import SwiftUI

struct CustomAppBackgroundView: View {
    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(
                        colorScheme == .dark ? 0.16 : 0.10
                    ),
                    Color(uiColor: .systemBackground),
                    Color.accentColor.opacity(
                        colorScheme == .dark ? 0.07 : 0.035
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 150, y: -260)

            Circle()
                .fill(Color.accentColor.opacity(0.05))
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .offset(x: -170, y: 330)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}


#Preview {
    CustomAppBackgroundView()
}

