//
//  PushNotificationManager.swift
//  erassvet
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Registers this device for push notifications and keeps the signed-in
/// user's FCM token in sync with Firestore ("users/{uid}.fcmToken"), which
/// is what the "sendChatPush" Cloud Function reads to know where to deliver
/// new-message alerts when the app isn't in the foreground.
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    private(set) var currentToken: String?

    private override init() {
        super.init()
    }

    /// Call once at launch (from AppDelegate).
    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    /// Prompts the system permission dialog (only shows once — iOS remembers
    /// the user's choice after that) and registers for APNs if granted.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                #if canImport(UIKit)
                UIApplication.shared.registerForRemoteNotifications()
                #endif
            }
        }
    }

    /// Pushes the current device token onto this user's profile document.
    /// Called after sign-in and whenever the token refreshes.
    func syncToken(uid: String) {
        guard let token = currentToken else { return }
        Task {
            try? await Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(["fcmToken": token], merge: true)
        }
    }

    /// Best-effort — removes this device's token from the account that's
    /// signing out, so a shared/test device (common while developing —
    /// switching between accounts like "sergey" and "Алексей 77") doesn't
    /// keep receiving push notifications meant for the previous account.
    func clearToken(uid: String) {
        Task {
            try? await Firestore.firestore()
                .collection("users")
                .document(uid)
                .updateData(["fcmToken": FieldValue.delete()])
        }
    }
}

extension PushNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.currentToken = fcmToken
            if let uid = Auth.auth().currentUser?.uid {
                self.syncToken(uid: uid)
            }
        }
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Shows the system banner/sound even while the app is in the foreground
    /// (by default iOS stays silent for foreground pushes unless told otherwise).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Tapping a notification just opens the app; the Чаты tab's own
        // unread badge and live listener take it from there. Deep-linking
        // straight into the specific chat could be added later by posting
        // the chatId from `response.notification.request.content.userInfo`
        // through NotificationCenter and observing it in ChatsView.
    }
}

/// Minimal UIKit app delegate — SwiftUI's `App` protocol has no hook for
/// `didRegisterForRemoteNotificationsWithDeviceToken`, which FCM needs to
/// finish associating this device's APNs token with a Firebase token.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PushNotificationManager.shared.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Best-effort — push just won't be available this session.
    }
}
