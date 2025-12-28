rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // USERS
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // CIRCLES (Groups)
    match /circles/{circleId} {
      // 1. Allow READ by any authenticated user 
      // (Required for "Join by Code" to work)
      allow read: if request.auth != null;
      
      // 2. Allow CREATE by any authenticated user
      allow create: if request.auth != null;
      
      // 3. Allow UPDATE if:
      //    a) User is already a member (Existing member update)
      //    b) OR User is joining (Adding themselves to memberIds)
      allow update: if request.auth != null && (
        request.auth.uid in resource.data.memberIds || 
        (
          request.resource.data.memberIds.size() == resource.data.memberIds.size() + 1 &&
          request.resource.data.memberIds.hasAll(resource.data.memberIds) &&
          request.auth.uid in request.resource.data.memberIds
        )
      );

      // Circle Messages
      match /messages/{messageId} {
        allow read, create: if request.auth != null && request.auth.uid in get(/databases/$(database)/documents/circles/$(circleId)).data.memberIds;
      }
    }

    // SESSIONS (Lobbies)
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;

      match /participants/{userId} {
        allow read, write: if request.auth != null;
      }
      match /messages/{messageId} {
        allow read, create: if request.auth != null;
      }
    }
  }
}
