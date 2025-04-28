import SwiftUI

struct ParentImageView: View {
    let image: UIImage?
    let color: Color
    
    var body: some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .shadow(radius: 3)
        } else {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 80, height: 80)
        }
    }
}
