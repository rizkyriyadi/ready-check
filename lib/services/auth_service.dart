import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  User? get user => _user;

  bool get isAuthenticated => _user != null;

  AuthService() {
    _user = _auth.currentUser; // Initialize synchronously
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _ensureUserInFirestore(user);
      }
      notifyListeners();
    });
  }

  /// Ensure user document exists in Firestore
  Future<void> _ensureUserInFirestore(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final doc = await userDoc.get();
      
      if (!doc.exists) {
        // Create user document
        await userDoc.set({
          'displayName': user.displayName ?? 'Anonymous',
          'photoUrl': user.photoURL ?? '',
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } else {
        // Update lastSeen
        await userDoc.update({
          'lastSeen': FieldValue.serverTimestamp(),
          'displayName': user.displayName ?? doc.data()?['displayName'] ?? 'Anonymous',
          'photoUrl': user.photoURL ?? doc.data()?['photoUrl'] ?? '',
        });
      }
    } catch (e) {
      debugPrint('Error ensuring user in Firestore: $e');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      
      // Ensure user is stored in Firestore
      if (userCredential.user != null) {
        await _ensureUserInFirestore(userCredential.user!);
      }
      
      return userCredential.user;
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  // Update Profile
  Future<void> updateDisplayName(String newName) async {
    if (_user == null) return;
    try {
      await _user!.updateDisplayName(newName);
      await _user!.reload();
      _user = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating name: $e");
      rethrow;
    }
  }

  Future<void> updateProfilePhoto(File imageFile) async {
    if (_user == null) return;
    try {
      final ref = _storage.ref().child('user_avatars').child('${_user!.uid}.jpg');
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      
      await _user!.updatePhotoURL(downloadUrl);
      await _user!.reload();
      _user = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating photo: $e");
      rethrow;
    }
  }
}
