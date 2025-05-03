import SwiftUI

struct SplashScreenView: View {
    @Binding var isActive: Bool
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.accentColor.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "calendar.circle.fill")
                    .resizable()
                    .frame(width: 90, height: 90)
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1.1 : 0.8)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
                Text("Ferien Buddy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Ferienverwaltung für Familien")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isActive = false
                }
            }
        }
    }
}
