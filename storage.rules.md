rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // User Avatars Folder
    // Match any file inside user_avatars
    match /user_avatars/{fileName} {
      allow read: if request.auth != null;
      // Allow write if the user is authenticated (Basic validation)
      // Ideally check if fileName matches userId, but for now allow auth users.
      allow write: if request.auth != null;
    }
  }
}
