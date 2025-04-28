import SwiftUI

struct ChildTypePicker: View {
    @Binding var selection: ChildType
    var body: some View {
        Picker("Typ", selection: $selection) {
            ForEach(ChildType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
}
