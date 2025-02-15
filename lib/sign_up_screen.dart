import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void signUp() async {
    try {
      // Create the user account
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Show a message to the user to check their email
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Account created successfully. Please check your email for verification.")),
        );
      }

      // Navigate back to the sign-in screen
      Navigator.pop(context);
    } catch (error) {
      // Handle sign-up errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sign Up Failed: ${error.toString()}")),
        );
      }
    }
  }

  // Method to resend verification email
  void resendVerificationEmail() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text("Verification email sent. Please check your inbox.")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No user is currently signed in.")),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Failed to resend verification email: ${error.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text("Sign Up"),
        centerTitle: true,
        backgroundColor: Colors.lightBlue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Password"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: signUp,
              child: Text("Sign Up"),
            ),
            TextButton(
              onPressed: resendVerificationEmail,
              child: Text("Resend Verification Email"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Return to the sign-in screen
              },
              child: Text("Already have an account? Sign In"),
            ),
          ],
        ),
      ),
    );
  }
}
