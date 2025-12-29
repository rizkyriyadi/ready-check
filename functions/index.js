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

    // Send data-only FCM message (NO notification payload)
    // This allows Flutter background handler to show fullScreenIntent notification
    const message = {
      data: {
        type: "summon",
        sessionId: sessionId,
        title: "⚡ READY CHECK!",
        body: `${session.activityTitle || "Your squad"} needs you!`,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
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

/**
 * Triggered when a new direct message (DM) is sent.
 * Sends FCM to the recipient.
 */
exports.onDirectMessage = functions.firestore
  .document("directChats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chatId = context.params.chatId;
    const senderId = message.senderId;
    const senderName = message.senderName || "Someone";
    const messageText = message.text || "";

    console.log(`New DM in chat ${chatId} from ${senderName}`);

    // Get chat to find the other participant
    let participants = [];
    try {
      const chatDoc = await db.collection("directChats").doc(chatId).get();
      if (chatDoc.exists) {
        participants = chatDoc.data().participants || [];
      }
    } catch (e) {
      console.error("Error getting chat:", e);
      return null;
    }

    // Find recipient (not the sender)
    const recipientId = participants.find(uid => uid !== senderId);
    if (!recipientId) {
      console.log("No recipient found");
      return null;
    }

    // Get recipient's FCM token
    let recipientToken = null;
    try {
      const userDoc = await db.collection("users").doc(recipientId).get();
      if (userDoc.exists) {
        recipientToken = userDoc.data().fcmToken;
      }
    } catch (e) {
      console.error("Error getting recipient token:", e);
      return null;
    }

    if (!recipientToken) {
      console.log("Recipient has no FCM token");
      return null;
    }

    // Truncate message
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
        type: "dm",
        chatId: chatId,
        senderId: senderId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "chat_channel",
        },
      },
      token: recipientToken,
    };

    try {
      const response = await messaging.send(fcmMessage);
      console.log(`Successfully sent DM notification: ${response}`);
      return response;
    } catch (error) {
      console.error("Error sending DM notification:", error);
      return null;
    }
  });
