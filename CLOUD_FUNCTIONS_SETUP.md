# Setup Background Call Notifications & Fix Audio

## 1. Fix Audio Issues (Token)
Your logs show `ErrorCodeType.errInvalidToken`. This means **App Certificate** is enabled in your Agora Console, but the app is sending an empty token.

**Solution (Choose one):**
*   **Option A (Recommended for Development):**
    1.  Go to [Agora Console](https://console.agora.io/)
    2.  Select your Project -> **Edit**
    3.  Find "App Certificate" and **Disable** it (or set to "No Certificate").
    4.  Wait 5-10 minutes.
    5.  Now the empty token `''` in the code will work.

*   **Option B (Secure/Production):**
    1.  You need to deploy a Token Server (backend) to generate valid tokens.
    2.  Update `CallService.dart` to fetch token from backend.

## 2. Enable Background Notifications
To show "Incoming Call" screen when the app is closed, you need a **Firebase Cloud Function** that sends a push notification when a call is started.

### Step 1: Initialize Cloud Functions
If you haven't already:
```bash
firebase init functions
# Select JavaScript
# Install dependencies
```

### Step 2: Add this code to `functions/index.js`

```javascript
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onCallCreated = functions.firestore
    .document("calls/{callId}")
    .onCreate(async (snapshot, context) => {
      const callData = snapshot.data();
      const callId = context.params.callId;
      const callerName = callData.callerName;
      const receiverIds = callData.receiverIds;

      console.log(`New call from ${callerName} to ${receiverIds.length} users`);

      // 1. Get FCM tokens for all receivers
      const tokens = [];
      for (const uid of receiverIds) {
        const userDoc = await admin.firestore().collection("users").doc(uid).get();
        if (userDoc.exists && userDoc.data().fcmToken) {
          tokens.push(userDoc.data().fcmToken);
        }
      }

      if (tokens.length === 0) {
        console.log("No tokens found for receivers");
        return null;
      }

      // 2. Send Data Message (High Priority)
      const payload = {
        data: {
            type: "call",
            callId: callId,
            callerName: callerName,
            isGroup: callData.receiverIds.length > 1 ? "true" : "false",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            ttl: 0, // Deliver immediately or drop
        },
        tokens: tokens, // Send to multiple devices
      };

      try {
        const response = await admin.messaging().sendMulticast(payload);
        console.log("Notifications sent:", response.successCount);
      } catch (error) {
        console.error("Error sending notification:", error);
      }
    });
```

### Step 3: Deploy
```bash
firebase deploy --only functions
```

Once deployed, when User A calls User B, Firebase will trigger this function -> Send FCM -> Android app handles it in background -> Shows Notification.
