//
//  VideoMetadataView.swift
//  clipr
//
//  Created by Spencer Byrne on 2/5/25.
//

import SwiftUI
import Kingfisher


struct VideoMetadataView: View {
    let video: Video
    let user: UserProfile
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var offset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0
    @GestureState private var gestureOffset: CGFloat = 0
    @State private var isCommenting = false
    @State private var commentText = ""
    @State private var keyboardHeight: CGFloat = 0
    
    // Sheet States
    private var smallHeight: CGFloat { 50 }  // Minimal height for content
    private var mediumHeight: CGFloat { UIScreen.main.bounds.height * 0.4 }  // Medium state
    private var commentHeight: CGFloat { UIScreen.main.bounds.height * 0.8 }  // Taller state for commenting
    
    // Shared animation parameters
    private let transitionSpring = Animation.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0)
    
    private var blurRadius: CGFloat {
        let progress = -offset / mediumHeight
        return min(progress * 30, 30)
    }
    
    init(video: Video, user: UserProfile) {
        self.video = video
        self.user = user
        _likeCount = State(initialValue: video.likeCount)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.frame(in: .global).height
            
            VStack(spacing: 0) {
                Spacer()
                
                // Sheet View
                ZStack(alignment: .top) {
                    BlurView(style: .systemThinMaterialDark)
                        .background(Color.black.opacity(-offset > smallHeight ? 0.9 : 0.5))
                        .cornerRadius(20, corners: [.topLeft, .topRight])
                        .animation(transitionSpring, value: -offset > smallHeight)
                    
                    VStack(spacing: 0) {
                        // Grabber
                        /*
                        Capsule()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 36, height: 4)
                            .padding(.top, 6)
                            .padding(.bottom, 4)
                            .contentShape(Rectangle())
                         */
                        
                        // Metadata content
                        HStack(alignment: .center, spacing: 12) {
                            // Left side - Profile pic and info
                            HStack(alignment: .center, spacing: 8) {
                                // Profile pic
                                Group {
                                    if let avatarId = user.avatarId,
                                       let avatarURL = AppwriteManager.shared.getAvatarURL(avatarId: avatarId) {
                                        KFImage(avatarURL)
                                            .placeholder {
                                                Circle()
                                                    .fill(Color.gray)
                                            }
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.gray)
                                            .frame(width: 32, height: 32)
                                    }
                                }
                                .animation(transitionSpring, value: -offset > smallHeight)
                                
                                // User info and caption stack
                                VStack(alignment: .leading, spacing: 1) {
                                    if let caption = video.caption, !caption.isEmpty {
                                        // Regular horizontal layout with caption
                                        VStack(alignment: .leading, spacing: 1) {
                                            HStack(alignment: .center, spacing: 4) {
                                                Text("@\(user.username ?? "unknown")")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(.white)
                                                Text("·")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.white.opacity(0.8))
                                                Text(video.timeAgo)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                            
                                            Text(caption)
                                                .foregroundColor(.white)
                                                .font(.system(size: -offset > smallHeight ? 13 : 12))
                                                .lineLimit(-offset > smallHeight ? nil : 2)
                                                .padding(.top, 1)
                                                .frame(minHeight: 32)
                                        }
                                    } else {
                                        // Vertical stack for no caption
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("@\(user.username ?? "unknown")")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text(video.timeAgo)
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                }
                                .animation(transitionSpring, value: -offset > smallHeight)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Right side - Stats
                            HStack(spacing: 16) {
                                Button(action: {
                                    withAnimation(transitionSpring) {
                                        isLiked.toggle()
                                        likeCount += isLiked ? 1 : -1
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: isLiked ? "heart.fill" : "heart")
                                            .font(.system(size: 20))
                                            .foregroundColor(isLiked ? .red : .white)
                                        Text("\(likeCount)")
                                            .font(.system(size: 11))
                                            .bold()
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Button(action: {
                                    withAnimation(transitionSpring) {
                                        isCommenting = true
                                        offset = -commentHeight
                                        lastOffset = offset
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "bubble.right.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                        Text("\(video.commentCount)")
                                            .font(.system(size: 11))
                                            .bold()
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .animation(transitionSpring, value: -offset > smallHeight)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        
                        // Expanded content
                        if -offset > smallHeight {
                            VStack(spacing: 16) {
                                Divider()
                                    .background(Color.white.opacity(0.2))
                                    .padding(.horizontal)
                                
                                Text("Comments")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                // Comments list
                                ScrollView {
                                    ForEach(0..<5) { _ in
                                        HStack {
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 32, height: 32)
                                            
                                            VStack(alignment: .leading) {
                                                Text("User")
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text("Comment text goes here")
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundColor(.white)
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                
                                // Comment input field
                                if isCommenting {
                                    HStack(spacing: 12) {
                                        TextField("Add a comment...", text: $commentText)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .foregroundColor(.black)
                                        
                                        Button(action: {
                                            // Submit comment
                                            commentText = ""
                                            hideKeyboard()
                                        }) {
                                            Image(systemName: "arrow.up.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                        }
                                        .disabled(commentText.isEmpty)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.bottom, keyboardHeight)
                                }
                            }
                            .padding()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .move(edge: .bottom))
                            ))
                            .animation(transitionSpring, value: -offset > smallHeight)
                        }
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            withAnimation(transitionSpring) {
                                if offset == 0 {
                                    offset = -mediumHeight
                                } else {
                                    offset = 0
                                }
                                lastOffset = offset
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .updating($gestureOffset) { value, out, _ in
                            if !isCommenting {  // Disable drag when commenting
                                out = value.translation.height
                                onChange()
                            }
                        }
                        .onEnded { value in
                            if !isCommenting {  // Disable drag when commenting
                                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                    let height = mediumHeight - smallHeight
                                    
                                    if -offset > smallHeight {
                                        if value.translation.height > 100 {
                                            offset = 0
                                            isCommenting = false
                                        } else {
                                            offset = -mediumHeight
                                        }
                                    } else {
                                        if value.translation.height < -100 || value.velocity.height < -200 {
                                            offset = -mediumHeight
                                        } else {
                                            offset = 0
                                            isCommenting = false
                                        }
                                    }
                                    
                                    lastOffset = offset
                                }
                            }
                        }
                )
                .allowsHitTesting(true)
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { _ in }
                        .onEnded { _ in }
                )
            }
            .offset(y: height)
            .offset(y: -smallHeight)
            .offset(y: offset)
            .offset(y: isCommenting ? -keyboardHeight : 0)
            .offset(y: -safeAreaInset)  // Adjust for bottom safe area
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                    keyboardHeight = keyboardFrame.height
                    
                    withAnimation(.spring()) {
                        offset = -commentHeight
                        lastOffset = offset
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                    if isCommenting {
                        withAnimation(.spring()) {
                            offset = -mediumHeight
                            lastOffset = offset
                        }
                        isCommenting = false
                    }
                }
            }
        }
    }
    
    private func onChange() {
        DispatchQueue.main.async {
            self.offset = gestureOffset + lastOffset
        }
    }
    
    private var safeAreaInset: CGFloat {
        let window = UIApplication.shared.windows.first
        return window?.safeAreaInsets.bottom ?? 0
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
    }
}

// Add this extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Test data for preview
extension Video {
    static let testData = Video(
        from: VideoDocument(
            id: "preview_id",
            collectionId: "collection_id",
            databaseId: "database_id",
            createdAt: "2024-02-05T12:00:00.000Z",
            updatedAt: "2024-02-05T12:00:00.000Z",
            permissions: ["read"],
            caption: "Check out this amazing video! 🎥 #trending #viral",
            likes: [],
            comments: [],
            videoId: "video_id",
            users: "testuser"
        ),
        userProfile: UserProfile(
            id: "user_id",
            collectionId: "users_collection",
            databaseId: "database_id",
            createdAt: "2024-02-05T12:00:00.000Z",
            updatedAt: "2024-02-05T12:00:00.000Z",
            permissions: ["read"],
            userId: "user123",
            username: "testuser",
            name: "Test User",
            phone: "+1234567890",
            avatarId: "67a3a9e98b42022aa1a3",
            email: "test@example.com"
        )
    )
}

#Preview {
    ZStack {
        // Background to simulate video content
        Color.blue
            .ignoresSafeArea()
        
        VideoMetadataView(
            video: Video.testData,
            user: Video.testData.users ?? UserProfile(
                id: "user_id",
                collectionId: "users_collection",
                databaseId: "database_id",
                createdAt: "2024-02-05T12:00:00.000Z",
                updatedAt: "2024-02-05T12:00:00.000Z",
                permissions: ["read"],
                userId: "user123",
                username: "testuser",
                name: "Test User",
                phone: "+1234567890",
                avatarId: "67a3a9e98b42022aa1a3",
                email: "test@example.com"
            )
        )
    }
}

// Add this extension to hide keyboard
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
