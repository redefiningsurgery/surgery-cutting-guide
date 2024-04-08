import SwiftUI

/// Centers content both vertically and horizontally.  Expands to meet whatever space is available.
struct Centered<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                content()
                Spacer()
            }
            Spacer()
        }
    }
}

#Preview {
    Centered {
        Text("hi")
    }
    .background {
        Color.blue
    }
}
  
