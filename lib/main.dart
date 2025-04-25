import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'screens/auth/sign_in_screen.dart';
import 'screens/device_registration_screen.dart';
import 'home_page.dart';
import 'services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'screens/customer/customer_dashboard.dart';

void main() async {
  // Set up error handling for the entire app
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    // Enable database persistence and logging
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setLoggingEnabled(true);

    runApp(MyApp());
  }, (error, stackTrace) {
    // Log the error to the console
    debugPrint('Unhandled error: $error');
    debugPrint('Stack trace: $stackTrace');

    // You could also report this to a crash reporting service
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(FirebaseAuth.instance),
        ),
        StreamProvider(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'IoT Device Control',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        routes: {
          '/': (context) => AuthenticationWrapper(),
          '/register-device': (context) => DeviceRegistrationScreen(),
          '/customer/dashboard': (context) => CustomerDashboard(),
        },
      ),
    );
  }
}

class AuthenticationWrapper extends StatefulWidget {
  @override
  _AuthenticationWrapperState createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  StreamSubscription<User?>? _authSubscription;
  DatabaseReference? _userDevicesRef;
  StreamSubscription<DatabaseEvent>? _devicesSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _checkEmailVerification(user);
      } else {
        _cleanupUserSession();
      }
    });
  }

  Future<void> _checkEmailVerification(User user) async {
    try {
      // Force token refresh and check email verification
      await user.getIdToken(true);
      await user.reload();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null && !currentUser.emailVerified) {
        // If email is not verified, sign out and show message
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please verify your email before signing in.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // If email is verified, sign out and show sign-in page
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verified! Please sign in to continue.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking email verification: $e");
      _cleanupUserSession();
    }
  }

  Future<void> _initializeUserSession(String uid) async {
    try {
      // Cleanup any existing listeners first
      _cleanupUserSession();

      // Setup new listeners
      _userDevicesRef = FirebaseDatabase.instance.ref('users/$uid/devices');
      _devicesSubscription = _userDevicesRef!.onValue.listen((event) {
        // Handle devices data
      }, onError: (error) {
        debugPrint("Devices listener error: $error");
        if (error is FirebaseException && error.code == 'permission-denied') {
          _handlePermissionError();
        }
      });
    } catch (e) {
      debugPrint("Error in _initializeUserSession: $e");
      _cleanupUserSession();
    }
  }

  void _cleanupUserSession() {
    try {
      _devicesSubscription?.cancel();
      _devicesSubscription = null;
      _userDevicesRef = null;
    } catch (e) {
      debugPrint("Error during cleanup: $e");
    }
  }

  void _handlePermissionError() {
    try {
      FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session expired. Please sign in again.')),
        );
      }
    } catch (e) {
      debugPrint("Error handling permission error: $e");
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cleanupUserSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();

    // Always show sign-in page
    return SignInScreen();
  }
}

// Global context access (use with caution)
BuildContext? globalContext;
