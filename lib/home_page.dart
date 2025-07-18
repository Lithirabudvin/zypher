import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/devices_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/customer/customer_dashboard.dart';
import 'screens/supplier/sell_products_screen.dart';
import 'screens/supplier/buy_eggs_screen.dart';
import 'screens/account_screen.dart';
import 'services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'widgets/app_drawer.dart';
import 'models/user_model.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);

        // Get user data from database
        final snapshot =
            await FirebaseDatabase.instance.ref('users/${user.uid}').get();

        if (snapshot.exists) {
          final userData = Map<String, dynamic>.from(snapshot.value as Map);
          setState(() {
            _userModel = UserModel.fromMap(userData);
          });
        }
      }
    } catch (e) {
      debugPrint("Error in initial state check: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('BSFix')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    // If no user is authenticated, show sign in page
    if (user == null) {
      return SignInScreen();
    }

    // If user is not email verified, show verification screen
    if (!user.emailVerified) {
      return EmailVerificationScreen();
    }

    // If user is a customer (previously distributor), show customer dashboard
    if (_userModel?.role == UserRole.customer) {
      return CustomerDashboard();
    }

    // For suppliers (previously customers), show the regular home page
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello ${_userModel?.name ?? "User"}!'),
        backgroundColor: Colors.green,
      ),
      drawer: AppDrawer(isHomePage: true, userRole: _userModel?.role),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;
          final isSmallScreen = screenHeight < 600;

          return Container(
            color: Colors.white,
            child: Stack(
              children: [
                // Background Image with Fade Effect
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.95),
                        Colors.white.withOpacity(0.8),
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.4),
                      ],
                      stops: [0.0, 0.3, 0.6, 1.0],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/bsf1.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                Column(
                  children: [
                    // Welcome Section
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.02,
                        horizontal: screenWidth * 0.05,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.shade700,
                            Colors.green.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                    // Main Content
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(screenWidth * 0.05),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.all(screenWidth * 0.05),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Welcome to BSFix',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Icon(
                                      Icons.eco,
                                      size: 35,
                                      color: Colors.green,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'BSFix is your one-stop platform for buying and selling Black Soldier Fly products. Whether you\'re a farmer, compost recycler, or sustainable product buyer, we connect you with the right people—eco-conscious and efficient.',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[800],
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                vertical: screenHeight * 0.015,
                                horizontal: screenWidth * 0.05,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 15,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.all(screenWidth * 0.04),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: GridView.count(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.3,
                                  children: [
                                    _buildQuickActionButton(
                                      icon: Icons.devices,
                                      label: 'My Devices',
                                      color: Colors.green,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  DevicesScreen()),
                                        );
                                      },
                                    ),
                                    _buildQuickActionButton(
                                      icon: Icons.shopping_cart,
                                      label: 'Sell Products',
                                      color: Colors.blue,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  SellProductsScreen()),
                                        );
                                      },
                                    ),
                                    _buildQuickActionButton(
                                      icon: Icons.egg,
                                      label: 'Buy Eggs',
                                      color: Colors.orange,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  BuyEggsScreen()),
                                        );
                                      },
                                    ),
                                    _buildQuickActionButton(
                                      icon: Icons.person,
                                      label: 'My Account',
                                      color: Colors.purple,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  AccountScreen()),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 35,
                  color: color,
                ),
              ),
              SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
