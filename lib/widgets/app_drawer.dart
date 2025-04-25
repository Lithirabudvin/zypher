import 'package:flutter/material.dart';
import '../screens/devices_screen.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../screens/supplier/sell_products_screen.dart';
import '../screens/supplier/buy_eggs_screen.dart';

class AppDrawer extends StatelessWidget {
  final bool isHomePage;
  final UserRole? userRole;

  const AppDrawer({Key? key, this.isHomePage = false, this.userRole})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Color(0xFFFFF8E1), // Light cream background
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'IoT Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            if (!isHomePage) ...[
              ListTile(
                leading: Icon(Icons.home, color: Colors.green),
                title: Text('Home'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.devices, color: Colors.green),
              title: Text('My Devices'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => DevicesScreen()));
              },
            ),
            if (userRole == UserRole.supplier) ...[
              Divider(),
              ListTile(
                leading: Icon(Icons.shopping_cart, color: Colors.blueAccent),
                title: Text('Sell Products'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SellProductsScreen()));
                },
              ),
              ListTile(
                leading: Icon(Icons.egg, color: Colors.orangeAccent),
                title: Text('Buy Eggs'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => BuyEggsScreen()));
                },
              ),
            ],
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthService>().signOut(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
