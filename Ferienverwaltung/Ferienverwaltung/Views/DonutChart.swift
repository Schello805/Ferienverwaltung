import SwiftUI

struct DonutChart: View {
    var progress: Double // 0.0 ... 1.0
    var label: String
    var valueText: String
    var color: Color = .accentColor
    
    @State private var animatedProgress: Double = 0.0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 16)
                .frame(width: 120, height: 120)
            Circle()
                .trim(from: 0.0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 120)
                .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
                .animation(.easeOut(duration: 1.0), value: animatedProgress)
            VStack(spacing: 4) {
                Text(valueText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            animatedProgress = progress
        }
    }
}

struct DonutChart_Previews: PreviewProvider {
    static var previews: some View {
        DonutChart(progress: 0.82, label: "Betreuungsquote", valueText: "82%")
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
