# Ready Check 🎮⚡

A Dota 2-inspired "Ready Check" mobile application built with Flutter and Firebase. Coordinate with your squad before jumping into battle!

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

## Features

### 🔥 Core Features
- **Circles (Squads)**: Create or join circles with friends using invite codes
- **Ready Check (Summon)**: Trigger a full-screen summon notification to all circle members
- **Real-time Chat**: Chat with your squad in each circle
- **Push Notifications**: Get notified even when the app is closed (FCM)

### ✨ UI/UX
- **Liquid Glass Design**: Modern dark theme with glassmorphism effects
- **Full-Screen Summon Overlay**: Phone-call style notification with 30s timer
- **Animated Results**: Green celebration or red failure animations
- **Profile Customization**: Edit display name and profile photo

### 📱 Technical Highlights
- Firebase Authentication (Google Sign-In)
- Cloud Firestore for real-time data
- Firebase Cloud Messaging (FCM)
- Cloud Functions for server-side notifications
- Full-screen intent support for lock screen notifications

## Getting Started

### Prerequisites
- Flutter SDK (^3.10.0)
- Firebase project with:
  - Authentication (Google Sign-In enabled)
  - Cloud Firestore
  - Cloud Messaging
  - Cloud Functions (Blaze plan required)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/rizkyriyadi/ready-check.git
cd ready-check
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add an Android app with package name: `com.yamdimologi.dotaready`
   - Download `google-services.json` and place in `android/app/`
   - Enable Google Sign-In in Authentication
   - Set up Firestore security rules (see `firestore.rules.md`)

4. **Deploy Cloud Functions**
```bash
cd functions
npm install
firebase deploy --only functions
```

5. **Run the app**
```bash
flutter run
```

## Project Structure

```
lib/
├── core/
│   └── theme/          # App theme configuration
├── models/             # Data models (Circle, Session, Message, etc.)
├── screens/
│   ├── auth/           # Login screens
│   ├── circles/        # Circle list and detail pages
│   ├── profile/        # User profile page
│   ├── session/        # Ready check overlay
│   └── widgets/        # Reusable widgets
└── services/           # Firebase services (Auth, Firestore, FCM)

functions/              # Cloud Functions for FCM triggers
```

## Screenshots

*Coming soon*

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License

This project is open source and available under the [MIT License](LICENSE).

## Author

**Rizky Riyadi** - [@rizkyriyadi](https://github.com/rizkyriyadi)

---

Made with ❤️ and Flutter
