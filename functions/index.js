/**
 * eRassvet — Cloud Functions
 *
 * Sends a push notification to the *other* participant of a chat whenever a
 * new message is created. This covers both "написать продавцу" (first
 * message on an ad) and ordinary replies, since both go through the same
 * chats/{chatId}/messages subcollection.
 *
 * Requires an FCM/APNs setup on the Firebase project (Project settings ->
 * Cloud Messaging -> upload an APNs Auth Key) before pushes will actually
 * be delivered to iOS devices — see the deploy notes in README.md.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

const db = getFirestore();
const messaging = getMessaging();

exports.sendChatPush = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const { chatId } = event.params;
    const chatSnap = await db.collection("chats").doc(chatId).get();
    const chat = chatSnap.data();
    if (!chat) return;

    const senderId = message.senderId;
    const recipientId = chat.sellerId === senderId ? chat.buyerId : chat.sellerId;
    const senderName = chat.sellerId === senderId ? chat.sellerName : chat.buyerName;
    if (!recipientId) return;

    const recipientSnap = await db.collection("users").doc(recipientId).get();
    const fcmToken = recipientSnap.data()?.fcmToken;
    if (!fcmToken) return; // recipient has no device registered — nothing to do

    const text = typeof message.text === "string" ? message.text : "";
    const body = text.length > 120 ? `${text.slice(0, 117)}...` : text;
    const badge = (chat.unread?.[recipientId] ?? 0) + 1;

    try {
      await messaging.send({
        token: fcmToken,
        notification: {
          title: senderName || "Новое сообщение",
          body: body || "Новое сообщение",
        },
        data: {
          chatId,
          type: "chat_message",
        },
        apns: {
          payload: {
            aps: {
              badge,
              sound: "default",
            },
          },
        },
      });
    } catch (error) {
      // Common benign case: token expired/uninstalled — clean it up so we
      // stop trying to send to a dead device.
      if (
        error?.code === "messaging/registration-token-not-registered" ||
        error?.code === "messaging/invalid-registration-token"
      ) {
        await db.collection("users").doc(recipientId).update({
          fcmToken: FieldValue.delete(),
        });
      } else {
        console.error("sendChatPush failed:", error);
      }
    }
  }
);
