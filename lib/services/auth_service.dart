import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  AuthService(this._firebaseAuth);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<User?> signIn(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Force token refresh and wait for completion
      await userCredential.user?.getIdToken(true);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Sign in error: ${e.code} - ${e.message}");
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String address,
    required String phoneNumber,
    required UserRole role,
  }) async {
    try {
      UserCredential result = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (result.user != null) {
        // Create user model with additional fields
        final userModel = UserModel(
          uid: result.user!.uid,
          email: email,
          name: name,
          address: address,
          phone: phoneNumber,
          role: role,
        );

        // Store user data in Realtime Database
        await _database.ref('users/${result.user!.uid}').set(userModel.toMap());

        // Send email verification
        await result.user?.sendEmailVerification();
      }

      return result.user;
    } catch (e) {
      throw e;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final snapshot = await _database.ref('users/$uid').get();
      if (snapshot.exists) {
        return UserModel.fromMap(
            Map<String, dynamic>.from(snapshot.value as Map));
      }
      return null;
    } catch (e) {
      debugPrint("Error getting user data: $e");
      return null;
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      // Cancel any pending operations
      await Future.delayed(Duration.zero);

      // Sign out from Firebase
      await _firebaseAuth.signOut();

      // Add a small delay to ensure complete cleanup
      await Future.delayed(Duration(milliseconds: 100));

      // Navigate to sign in page
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      debugPrint("Sign out error: $e");
      // Don't rethrow the error, just log it
      // This prevents the app from crashing if there's an error during sign out
    }
  }
}
