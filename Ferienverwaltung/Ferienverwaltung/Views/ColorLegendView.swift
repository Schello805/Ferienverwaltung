import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct ColorLegendView: View {
    @AppStorage("legendColorUnattended") private var colorUnattendedHex: String = "#C5C5C5" // hellgrau
    @AppStorage("legendColorAttended") private var colorAttendedHex: String = "#FFC107" // orange

    var body: some View {
        HStack(spacing: 16) {
            Label { Text("Ferientag ohne Betreuung") } icon: { Circle().fill(Color(hex: colorUnattendedHex)).frame(width: 14, height: 14) }
            Label { Text("Ferientag mit Betreuung") } icon: { Circle().fill(Color(hex: colorAttendedHex)).frame(width: 14, height: 14) }
        }
        .font(.caption)
        .padding(.vertical, 4)
    }
}

struct ColorLegendView_Previews: PreviewProvider {
    static var previews: some View {
        ColorLegendView()
            .previewLayout(.sizeThatFits)
    }
}
