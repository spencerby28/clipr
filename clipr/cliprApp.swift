//
//  cliprApp.swift
//  clipr
//
//  Created by Spencer Byrne on 2/3/25.
//

import SwiftUI
import UserNotifications

class NavigationCoordinator {
    static let shared = NavigationCoordinator()
    
    private init() {
        // Initialize with the shared NavigationState
        self.navigationState = NavigationState.shared
    }
    
    // Using non-optional navigationState since we know it will always exist
    var navigationState: NavigationState
    
    func navigateToCamera() {
        DispatchQueue.main.async {
            print("NavigationCoordinator attempting to navigate to camera")
            self.navigationState.navigateTo(.camera)
            print("Navigation executed")
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var app: cliprApp?
    
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
        return [.sound, .banner, .list]
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        print("Received notification with userInfo: \(userInfo)")
        
        var pageData: String?
        
        if let aps = userInfo["aps"] as? [String: Any],
           let data = aps["data"] as? [String: Any],
           let pageDataValue = data["pageData"] as? String {
            pageData = pageDataValue
        }
        
        if let pageData = pageData {
            print("pageData = ", pageData)
            switch pageData {
            case "camera":
                NavigationCoordinator.shared.navigateToCamera()
                print("attempting to nav to camera")
            default:
                break
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
    
    
    func testLocalNotificationWithSound() {
        let content = UNMutableNotificationContent()
        content.title = "Test Sound"
        content.body = "Testing custom sound"
        
        // Create sound with more detailed error checking
        let soundName = "stab.caf"
        let sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        content.sound = sound
        
        // Print bundle information for debugging
        if let soundURL = Bundle.main.url(forResource: "stab", withExtension: "caf") {
            print("Sound file found at: \(soundURL)")
        } else {
            print("⚠️ Sound file not found in bundle!")
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                          content: content,
                                          trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled successfully with sound: \(soundName)")
            }
        }
    }
}

@main
class cliprApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var navigationState = NavigationState.shared
    @StateObject private var videoManager = VideoLoadingManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    required init() {
        appDelegate.app = self
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .environmentObject(navigationState)
                    .environmentObject(videoManager)
                    .task {
                        self.notificationManager.requestAuthorization()
                    }
            }
        }
    }
}
