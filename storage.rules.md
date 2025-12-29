rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // Chat images - participants can upload and read
    match /chat_images/{fileName} {
      // Anyone authenticated can upload chat images
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024  // Max 5MB
                   && request.resource.contentType.matches('image/.*');
      // Anyone authenticated can read chat images
      allow read: if request.auth != null;
    }
    
    // User profile images
    match /profile_images/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId
                   && request.resource.size < 2 * 1024 * 1024  // Max 2MB
                   && request.resource.contentType.matches('image/.*');
    }
    
    // Circle images
    match /circle_images/{circleId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
