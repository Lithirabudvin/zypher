import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message:
              'Please verify your email first. A new verification email has been sent.',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  Future<UserCredential?> signUpWithEmailAndPassword(
      String email, String password, String name, UserRole role) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email
      await userCredential.user!.sendEmailVerification();

      // Create user profile in database
      final user = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        name: name,
        role: role,
      );

      await _database.child('users/${user.uid}').set(user.toMap());

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final snapshot = await _database.child('users/$uid').get();
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
      await _auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw e;
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
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email
      await userCredential.user!.sendEmailVerification();

      // Create user profile in database
      final user = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        name: name,
        address: address,
        phone: phoneNumber,
        role: role,
      );

      await _database.child('users/${user.uid}').set(user.toMap());
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }
}
