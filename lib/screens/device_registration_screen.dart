import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  @override
  _DeviceRegistrationScreenState createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _deviceNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _registerDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final deviceId = _deviceIdController.text.trim();
      final deviceName = _deviceNameController.text.trim();

      final deviceRef = FirebaseDatabase.instance.ref('devices/$deviceId');
      final deviceSnapshot = await deviceRef.get();

      // Check if device exists and is already owned by someone else
      if (deviceSnapshot.exists &&
          deviceSnapshot.child('owner').exists &&
          deviceSnapshot.child('owner').value != user.uid) {
        throw Exception('Device already registered by another user');
      }

      // Create or update the device node with owner and name
      await deviceRef.update({
        'name': deviceName,
        'owner': user.uid,
        // Initialize config fields if necessary when creating for the first time
        if (!deviceSnapshot.exists) 'config/brightness': 128,
        if (!deviceSnapshot.exists) 'config/moist_device': 0,
        if (!deviceSnapshot.exists) 'config/compost_state': 0,
        // Initialize sensor_data fields if necessary when creating for the first time
        if (!deviceSnapshot.exists) 'sensor_data/temperature': 0.0,
        if (!deviceSnapshot.exists) 'sensor_data/humidity': 0.0,
        if (!deviceSnapshot.exists) 'sensor_data/light': 0.0,
        if (!deviceSnapshot.exists) 'sensor_data/compose_level': 0.0,
        // Add other default sensor/config values here if needed
      });

      // Add device to user's devices list
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/devices/$deviceId')
          .set(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device registered successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register device: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register New Device'),
        backgroundColor: Colors.green,
      ),
      body: Container(
        color: Color(0xFFFFF8E1),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Container(
                constraints: BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_to_queue,
                          size: 80,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: 32),
                      Text(
                        'Add New Device',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Enter your device details below',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 40),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _deviceIdController,
                                decoration: InputDecoration(
                                  labelText: 'Device ID',
                                  hintText: 'Enter the device ID',
                                  prefixIcon:
                                      Icon(Icons.qr_code, color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.green, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter the device ID';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 24),
                              TextFormField(
                                controller: _deviceNameController,
                                decoration: InputDecoration(
                                  labelText: 'Device Name',
                                  hintText: 'Enter a name for your device',
                                  prefixIcon:
                                      Icon(Icons.edit, color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.green, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a device name';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 32),
                              _isLoading
                                  ? Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.green))
                                  : ElevatedButton(
                                      onPressed: _registerDevice,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding:
                                            EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        minimumSize: Size(double.infinity, 50),
                                      ),
                                      child: Text(
                                        'Register Device',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
