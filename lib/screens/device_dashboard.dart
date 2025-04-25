import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'tabs/environment_tab.dart';
import 'tabs/compost_tab.dart';
import 'tabs/thermal_details_tab.dart';
import '../widgets/app_drawer.dart';
import '../models/user_model.dart';

// Enum to represent device types based on ID prefix
enum DeviceType { compost, egg, unknown }

class DeviceDashboard extends StatefulWidget {
  final String deviceId;

  const DeviceDashboard({Key? key, required this.deviceId}) : super(key: key);

  @override
  _DeviceDashboardState createState() => _DeviceDashboardState();
}

class _DeviceDashboardState extends State<DeviceDashboard> {
  int _currentIndex = 0;
  late DatabaseReference _dbRef;
  String _deviceName = '';
  DeviceType _deviceType = DeviceType.unknown;
  UserModel? _userModel;
  bool _isUserDataLoading = true;

  // Lists to hold the currently active tabs and nav items
  List<Widget> _tabs = [];
  List<BottomNavigationBarItem> _navBarItems = [];

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instance.ref();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _determineDeviceTypeAndConfigureTabs();
    await _loadDeviceName();
    await _loadUserData();
    if (mounted) {
      setState(() {
        _isUserDataLoading = false;
      });
    }
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
        debugPrint("Error loading user data in DeviceDashboard: $e");
      }
    }
  }

  void _determineDeviceTypeAndConfigureTabs() {
    // Check for hyphenated prefixes now
    if (widget.deviceId.startsWith('compost-')) {
      _deviceType = DeviceType.compost;
    } else if (widget.deviceId.startsWith('egg-')) {
      _deviceType = DeviceType.egg;
    } else {
      _deviceType = DeviceType.unknown;
    }
    _buildTabs();
  }

  void _buildTabs() {
    _tabs = [];
    _navBarItems = [];

    // Environment Tab (for egg type)
    if (_deviceType == DeviceType.egg) {
      _tabs.add(EnvironmentTab(deviceId: widget.deviceId));
      _navBarItems.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.cloud_outlined),
          activeIcon: Icon(Icons.cloud),
          label: 'Environment',
        ),
      );
    }

    // Compost and Thermal Tabs (for compost type)
    if (_deviceType == DeviceType.compost) {
      _tabs.add(CompostTab(deviceId: widget.deviceId));
      _navBarItems.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.recycling_outlined),
          activeIcon: Icon(Icons.recycling),
          label: 'Compost',
        ),
      );

      _tabs.add(ThermalDetailsTab(deviceId: widget.deviceId));
      _navBarItems.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.thermostat_outlined),
          activeIcon: Icon(Icons.thermostat),
          label: 'Thermal',
        ),
      );
    }

    // Reset index if it's out of bounds for the new tab set
    if (_currentIndex >= _tabs.length) {
      _currentIndex = 0;
    }
  }

  Future<void> _loadDeviceName() async {
    try {
      final snapshot =
          await _dbRef.child('devices/${widget.deviceId}/name').get();
      if (snapshot.exists && mounted) {
        setState(() {
          _deviceName = snapshot.value.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading device name: $e');
    }
  }

  // Simplified title logic - just show device name if available
  String get _appBarTitle {
    if (_deviceName.isNotEmpty) {
      return _deviceName;
    }
    // Determine a title based on type if name isn't loaded yet
    switch (_deviceType) {
      case DeviceType.compost:
        return 'Compost Device';
      case DeviceType.egg:
        return 'Egg Device';
      default:
        return 'Device Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUserDataLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        backgroundColor: Colors.green,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: Container(
        color: Color(0xFFFFF8E1),
        // Handle case where no tabs are defined for the type
        child: _tabs.isEmpty
            ? Center(
                child: Text(
                  'Unsupported or unknown device type.',
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              )
            : IndexedStack(
                index: _currentIndex,
                children: _tabs, // Use the dynamic list of tabs
              ),
      ),
      // Only show BottomNavigationBar if there are 2 or more items to show
      bottomNavigationBar: _navBarItems.length < 2
          ? null
          : Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                selectedItemColor: Colors.green,
                unselectedItemColor: Colors.grey[600],
                selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                elevation: 0,
                items: _navBarItems,
              ),
            ),
    );
  }
}
