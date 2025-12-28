const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Triggered when a new session (Ready Check) is created.
 * Sends FCM to all participants.
 */
exports.onSessionCreate = functions.firestore
  .document("sessions/{sessionId}")
  .onCreate(async (snap, context) => {
    const session = snap.data();
    const sessionId = context.params.sessionId;
    const participants = session.participants || [];
    const hostId = session.hostId;

    console.log(`New session created: ${sessionId} with ${participants.length} participants`);

    // Get FCM tokens for all participants (except host)
    const tokens = [];
    for (const uid of participants) {
      if (uid === hostId) continue; // Skip host (they created it)
      
      try {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmToken) {
            tokens.push(userData.fcmToken);
          }
        }
      } catch (e) {
        console.error(`Error getting token for user ${uid}:`, e);
      }
    }

    if (tokens.length === 0) {
      console.log("No tokens to send to");
      return null;
    }

    // Send FCM message
    const message = {
      notification: {
        title: "⚡ READY CHECK!",
        body: `${session.activityTitle || "Your squad"} needs you!`,
      },
      data: {
        type: "summon",
        sessionId: sessionId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "summon_channel",
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      tokens: tokens,
    };

    try {
      const response = await messaging.sendEachForMulticast(message);
      console.log(`Successfully sent message: ${response.successCount} success, ${response.failureCount} failures`);
      return response;
    } catch (error) {
      console.error("Error sending message:", error);
      return null;
    }
  });

/**
 * Triggered when a new message is sent in a circle chat.
 * Sends FCM to all circle members except sender.
 */
exports.onCircleMessage = functions.firestore
  .document("circles/{circleId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const circleId = context.params.circleId;
    const senderId = message.senderId;
    const senderName = message.senderName || "Someone";
    const messageText = message.text || "";

    console.log(`New message in circle ${circleId} from ${senderName}`);

    // Get circle to find members
    let members = [];
    try {
      const circleDoc = await db.collection("circles").doc(circleId).get();
      if (circleDoc.exists) {
        members = circleDoc.data().memberIds || [];
      }
    } catch (e) {
      console.error("Error getting circle:", e);
      return null;
    }

    // Get FCM tokens for all members except sender
    const tokens = [];
    for (const uid of members) {
      if (uid === senderId) continue;
      
      try {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmToken) {
            tokens.push(userData.fcmToken);
          }
        }
      } catch (e) {
        console.error(`Error getting token for user ${uid}:`, e);
      }
    }

    if (tokens.length === 0) {
      console.log("No tokens to send to");
      return null;
    }

    // Truncate message for notification
    const truncatedText = messageText.length > 100 
      ? messageText.substring(0, 100) + "..." 
      : messageText;

    // Send FCM message
    const fcmMessage = {
      notification: {
        title: senderName,
        body: truncatedText,
      },
      data: {
        type: "chat",
        circleId: circleId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "chat_channel",
        },
      },
      tokens: tokens,
    };

    try {
      const response = await messaging.sendEachForMulticast(fcmMessage);
      console.log(`Successfully sent chat notification: ${response.successCount} success`);
      return response;
    } catch (error) {
      console.error("Error sending chat notification:", error);
      return null;
    }
  });
