import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/device_model.dart';
import 'device_dashboard.dart';
import '../widgets/app_drawer.dart';
import '../models/user_model.dart';

class DevicesScreen extends StatefulWidget {
  @override
  _DevicesScreenState createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<Device> _devices = [];
  bool _isLoading = true;
  String? _errorMessage;
  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _loadDevices();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot =
            await FirebaseDatabase.instance.ref('users/${user.uid}').get();

        if (snapshot.exists && snapshot.value != null && mounted) {
          final userData = Map<String, dynamic>.from(snapshot.value as Map);
          setState(() {
            _userModel = UserModel.fromMap(userData);
          });
        }
      } catch (e) {
        debugPrint("Error loading user data in DevicesScreen: $e");
      }
    } else {
      if (mounted) {
        setState(() => _errorMessage = "User not authenticated");
      }
    }
  }

  Future<void> _loadDevices() async {
    if (mounted) setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final dbRef = FirebaseDatabase.instance.ref();

      final userDevicesSnapshot =
          await dbRef.child('users/${user.uid}/devices').get();

      if (!userDevicesSnapshot.exists || userDevicesSnapshot.value == null) {
        if (mounted) {
          setState(() {
            _devices = [];
            _isLoading = false;
          });
        }
        return;
      }

      final deviceIds =
          Map<String, dynamic>.from(userDevicesSnapshot.value as Map)
              .keys
              .toList();
      final devices = <Device>[];

      for (final deviceId in deviceIds) {
        final deviceSnapshot = await dbRef.child('devices/$deviceId').get();
        if (deviceSnapshot.exists && deviceSnapshot.value != null) {
          try {
            devices.add(Device.fromRTDB(
              deviceId,
              Map<dynamic, dynamic>.from(deviceSnapshot.value as Map),
            ));
          } catch (e) {
            debugPrint("Error parsing device $deviceId: $e");
          }
        }
      }

      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading devices: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading devices: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Devices'),
        backgroundColor: Colors.green,
      ),
      drawer: AppDrawer(userRole: _userModel?.role),
      body: Container(
        color: Color(0xFFFFF8E1),
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/register-device'),
        backgroundColor: Colors.green,
        icon: Icon(Icons.add_circle_outline),
        label: Text('Add Device'),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadDevices,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 100,
              color: Colors.green,
            ),
            SizedBox(height: 24),
            Text(
              'No devices registered yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Add your first IoT device to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register-device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.add),
              label: Text(
                'Add Device',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.devices,
                color: Colors.green,
                size: 32,
              ),
            ),
            title: Text(
              device.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Device ID: ${device.id}',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.green,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceDashboard(deviceId: device.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
