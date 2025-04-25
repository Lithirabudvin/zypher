import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class EnvironmentTab extends StatefulWidget {
  final String deviceId;

  const EnvironmentTab({Key? key, required this.deviceId}) : super(key: key);

  @override
  _EnvironmentTabState createState() => _EnvironmentTabState();
}

class _EnvironmentTabState extends State<EnvironmentTab> {
  double _humidity = 0.0;
  double _temperature = 0.0;
  double _lightIntensity = 0.0;
  bool _isMoistDeviceActive = false;
  bool _isTemperatureControlActive = false;
  bool _isBrightnessManual = false;
  double _brightnessValue = 0.0;
  bool _isLoading = true;
  late DatabaseReference _dbRef;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instance.ref();
    _setupSensorDataListener();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _setupSensorDataListener() {
    _dbRef.child('devices/${widget.deviceId}').onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        // Device data deleted or somehow null, stop loading and potentially show error
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Use try-catch or null checks for safer data extraction
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Check if config exists and get moist_device state (provide default if missing)
        bool isMoistActive = false;
        bool isTempControlActive = false;
        bool isBrightnessManual = false;
        double brightnessValue = 0.0;
        if (data['config'] != null) {
          final config = Map<String, dynamic>.from(data['config'] as Map);
          isMoistActive = (config['moist_device'] ?? 0) == 1;
          isTempControlActive = (config['temperature_control'] ?? 0) == 1;
          isBrightnessManual = (config['brightness_mode'] ?? 0) == 1;
          // Convert 0-255 range to percentage (0-100)
          brightnessValue =
              ((config['brightness'] ?? 0).toDouble() / 255) * 100;
        }

        // Check if sensor_data exists before accessing
        double currentHumidity = 0.0;
        double currentTemperature = 0.0;
        double currentLightIntensity = 0.0;
        if (data['sensor_data'] != null) {
          final sensorData =
              Map<String, dynamic>.from(data['sensor_data'] as Map);
          // Use double.tryParse for safer conversion, provide default 0.0 if null or invalid
          currentHumidity =
              double.tryParse(sensorData['humidity']?.toString() ?? '0.0') ??
                  0.0;
          currentTemperature =
              double.tryParse(sensorData['temperature']?.toString() ?? '0.0') ??
                  0.0;
          currentLightIntensity =
              double.tryParse(sensorData['light']?.toString() ?? '0.0') ?? 0.0;
        }

        // Update state only if mounted
        if (mounted) {
          setState(() {
            _humidity = currentHumidity;
            _temperature = currentTemperature;
            _lightIntensity = currentLightIntensity;
            _isMoistDeviceActive = isMoistActive;
            _isTemperatureControlActive = isTempControlActive;
            _isBrightnessManual = isBrightnessManual;
            _brightnessValue = brightnessValue;
            _isLoading = false; // Data loaded (or defaults used)
          });
        }
      } catch (e) {
        debugPrint("Error processing device data in EnvironmentTab: $e");
        // Optionally handle error state in UI
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _toggleMoistDevice() async {
    final newState = !_isMoistDeviceActive;
    try {
      await _dbRef.child('devices/${widget.deviceId}/config').update({
        'moist_device': newState ? 1 : 0,
      });
      setState(() => _isMoistDeviceActive = newState);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update device state'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.thermostat,
                            label: 'Temperature',
                            value: '${_temperature.toStringAsFixed(1)}°C',
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.water_drop,
                            label: 'Humidity',
                            value: '${_humidity.toStringAsFixed(1)}%',
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildMetricCard(
                      icon: Icons.light_mode,
                      label: 'Light Intensity',
                      value: '${_lightIntensity.toStringAsFixed(1)} lux',
                      color: Colors.yellow[700]!,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        'Moist Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _isMoistDeviceActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color:
                              _isMoistDeviceActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      value: _isMoistDeviceActive,
                      onChanged: (value) => _toggleMoistDevice(),
                      activeColor: Colors.green,
                      secondary: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.water,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text(
                        'Temperature Control',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _isTemperatureControlActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: _isTemperatureControlActive
                              ? Colors.orange
                              : Colors.grey,
                        ),
                      ),
                      value: _isTemperatureControlActive,
                      onChanged: (value) => _toggleTemperatureControl(),
                      activeColor: Colors.orange,
                      secondary: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.thermostat,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text(
                        'Brightness Control',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isBrightnessManual
                                ? 'Manual Mode'
                                : 'Default Mode',
                            style: TextStyle(
                              color: _isBrightnessManual
                                  ? Colors.yellow[700]
                                  : Colors.grey,
                            ),
                          ),
                          if (_isBrightnessManual) ...[
                            SizedBox(height: 8),
                            Slider(
                              value: _brightnessValue,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              label: '${_brightnessValue.round()}%',
                              onChanged: (value) => _updateBrightness(value),
                              onChangeEnd: (value) {
                                // Ensure the final value is saved immediately when slider is released
                                _debounceTimer?.cancel();
                                _updateBrightness(value);
                              },
                              activeColor: Colors.yellow[700],
                            ),
                          ],
                        ],
                      ),
                      trailing: Switch(
                        value: _isBrightnessManual,
                        onChanged: (value) => _toggleBrightnessMode(value),
                        activeColor: Colors.yellow[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTemperatureControl() async {
    final newState = !_isTemperatureControlActive;
    try {
      await _dbRef.child('devices/${widget.deviceId}/config').update({
        'temperature_control': newState ? 1 : 0,
      });
      setState(() => _isTemperatureControlActive = newState);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update temperature control'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleBrightnessMode(bool isManual) async {
    try {
      await _dbRef.child('devices/${widget.deviceId}/config').update({
        'brightness_mode': isManual ? 1 : 0,
      });
      setState(() => _isBrightnessManual = isManual);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update brightness mode'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateBrightness(double value) async {
    // Update UI immediately for smooth slider movement
    setState(() => _brightnessValue = value);

    // Cancel any pending debounce timer
    _debounceTimer?.cancel();

    // Set a new debounce timer
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        // Convert percentage (0-100) to 0-255 range for database
        int brightnessValue = ((value / 100) * 255).round();

        // Update both the brightness value and mode in the light control config
        await _dbRef.child('devices/${widget.deviceId}/config').update({
          'brightness': brightnessValue,
          'brightness_mode': _isBrightnessManual ? 1 : 0,
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update brightness value'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
}
