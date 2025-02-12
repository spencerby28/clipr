//
//  cliprApp.swift
//  clipr
//
//  Created by Spencer Byrne on 2/3/25.
//

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var navigationState: NavigationState?
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%.2hhx", $0) }.joined()
        print("APNS token: \(token)")
        UserDefaults.standard.set(token, forKey: "apnsToken")
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        ///shows alert even when app is active
        return [.sound, .banner]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        print("Received notification with userInfo: \(userInfo)")
        
        var pageData: String?
        
        // Extract pageData from aps dictionary
        if let aps = userInfo["aps"] as? [String: Any],
           let data = aps["data"] as? [String: Any],
           let pageDataValue = data["pageData"] as? String {
            pageData = pageDataValue
        }
        
        if let pageData = pageData {
            print("pageData = ", pageData)
            await MainActor.run {
                switch pageData {
                case "camera":
                    navigationState?.navigateTo(.camera)
                    print("attempting to nav to camera")
                default:
                    break
                }
            }
        } else {
            print("No pageData found in notification")
            if let aps = userInfo["aps"] as? [String: Any] {
                print("APS content: \(aps)")
            }
        }
    }
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var isAuthorized = false
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.registerForRemoteNotifications()
                }
            }
            if let error = error {
                print("Error requesting notification authorization: \(error.localizedDescription)")
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

@main
struct cliprApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var navigationState = NavigationState()
    @StateObject private var videoManager = VideoLoadingManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        appDelegate.navigationState = navigationState
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .environmentObject(navigationState)
            .environmentObject(videoManager)
            .task {
                notificationManager.requestAuthorization()
            }
        }
    }
}
