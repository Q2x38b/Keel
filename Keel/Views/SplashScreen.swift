import SwiftUI

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.background
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "helm")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.white)

                Text("Keel")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    SplashScreen()
        .preferredColorScheme(.dark)
}
