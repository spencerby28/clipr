import SwiftUI

struct FeedView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<10) { index in
                        VideoPlaceholderView(index: index)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .scrollTargetBehavior(.paging)
        }
    }
}

struct VideoPlaceholderView: View {
    let index: Int
    
    var body: some View {
        ZStack {
            Color(hue: Double(index) / 10, saturation: 0.8, brightness: 0.8)
            
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading) {
                        Text("Username")
                            .font(.headline)
                        Text("Video description")
                            .font(.subheadline)
                    }
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Button(action: {}) {
                            Image(systemName: "heart")
                                .font(.title)
                        }
                        Button(action: {}) {
                            Image(systemName: "message")
                                .font(.title)
                        }
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title)
                        }
                    }
                }
                .padding()
                .foregroundColor(.white)
            }
        }
    }
} 