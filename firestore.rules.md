rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // USERS
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
      
      // Friends subcollection
      match /friends/{friendId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && (
          request.auth.uid == userId || request.auth.uid == friendId
        );
      }
      
      // Friend Requests
      match /friendRequests/{requestId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow create: if request.auth != null;
        allow delete: if request.auth != null && (
          request.auth.uid == userId || request.auth.uid == requestId
        );
      }
      
      // Sent Requests
      match /sentRequests/{targetId} {
        allow read: if request.auth != null && (
          request.auth.uid == userId || request.auth.uid == targetId
        );
        allow write: if request.auth != null && (
          request.auth.uid == userId || request.auth.uid == targetId
        );
      }
    }

    // CIRCLES (Groups)
    match /circles/{circleId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && (
        request.auth.uid in resource.data.memberIds || 
        (
          request.resource.data.memberIds.size() == resource.data.memberIds.size() + 1 &&
          request.resource.data.memberIds.hasAll(resource.data.memberIds) &&
          request.auth.uid in request.resource.data.memberIds
        )
      );

      match /messages/{messageId} {
        allow read, create: if request.auth != null && request.auth.uid in get(/databases/$(database)/documents/circles/$(circleId)).data.memberIds;
      }
    }

    // DIRECT CHATS (DMs)
    match /directChats/{chatId} {
      // Read: any auth user can read (needed to check if chat exists)
      allow read: if request.auth != null;
      // Create: user must be in participants
      allow create: if request.auth != null && request.auth.uid in request.resource.data.participants;
      // Update: participants can update (for typing, unread, lastMessage)
      allow update: if request.auth != null && request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        allow read: if request.auth != null && request.auth.uid in get(/databases/$(database)/documents/directChats/$(chatId)).data.participants;
        allow create: if request.auth != null && request.auth.uid in get(/databases/$(database)/documents/directChats/$(chatId)).data.participants;
        // Allow update for read receipts
        allow update: if request.auth != null && request.auth.uid in get(/databases/$(database)/documents/directChats/$(chatId)).data.participants;
      }
    }

    // SESSIONS (Lobbies)
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;

      match /participants/{partId} {
        allow read, write: if request.auth != null;
      }
      match /messages/{messageId} {
        allow read, create: if request.auth != null;
      }
    }

    // CALLS (Voice/Video)
    match /calls/{callId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && (
        request.auth.uid == resource.data.callerId ||
        request.auth.uid in resource.data.receiverIds
      );
    }
  }
}
