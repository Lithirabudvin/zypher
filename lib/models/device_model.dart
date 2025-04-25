import 'package:flutter/foundation.dart';

class Device {
  final String id;
  final String ownerId;
  final String name;
  final Map<String, dynamic> config;
  final Map<String, dynamic> sensorData;
  final DateTime? createdAt;

  Device({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.config,
    required this.sensorData,
    this.createdAt,
  });

  factory Device.fromRTDB(String id, Map<dynamic, dynamic> data) {
    return Device(
      id: id,
      ownerId: _validateString(data['owner'], 'ownerId'),
      name: _validateString(data['name'], 'name', fallback: 'Unnamed Device'),
      config: _validateConfig(data['config'] ?? {}),
      sensorData: _validateSensorData(data['sensor_data'] ?? {}),
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int)
          : null,
    );
  }

  // Getters with strict type checking
  double get temperature => _getDouble(sensorData['temperature']);
  double get humidity => _getDouble(sensorData['humidity'], max: 100);
  double get light => _getDouble(sensorData['light']);
  double get compostLevel => _getDouble(sensorData['compose_level'], max: 100);
  int get brightness => _getInt(config['brightness'], min: 0, max: 255);
  bool get moistDeviceState => config['moist_device'] == 1;
  bool get compostState => config['compost_state'] == 1;

  // Utility methods
  Map<String, dynamic> toJson() {
    return {
      'owner': ownerId,
      'name': name,
      'config': config,
      'sensor_data': sensorData,
      if (createdAt != null) 'createdAt': createdAt!.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': 'Online', // You can make this dynamic based on your needs
    };
  }

  // Private validation helpers
  static String _validateString(dynamic value, String fieldName,
      {String fallback = ''}) {
    if (value is String) return value;
    debugPrint('Invalid $fieldName: $value');
    return fallback;
  }

  static Map<String, dynamic> _validateConfig(dynamic config) {
    final defaultConfig = {
      'brightness': 100,
      'moist_device': 0,
      'compost_state': 0,
    };

    if (config is! Map) return defaultConfig;

    return {
      'brightness':
          _getInt(config['brightness'], min: 0, max: 255, fallback: 100),
      'moist_device': config['moist_device'] == 1 ? 1 : 0,
      'compost_state': config['compost_state'] == 1 ? 1 : 0,
    };
  }

  static Map<String, dynamic> _validateSensorData(dynamic sensorData) {
    final defaultData = {
      'temperature': 0.0,
      'humidity': 0.0,
      'light': 0.0,
      'compose_level': 0.0,
    };

    if (sensorData is! Map) return defaultData;

    return {
      'temperature': _getDouble(sensorData['temperature']),
      'humidity': _getDouble(sensorData['humidity'], max: 100),
      'light': _getDouble(sensorData['light']),
      'compose_level': _getDouble(sensorData['compose_level'], max: 100),
    };
  }

  static double _getDouble(dynamic value, {double min = 0, double? max}) {
    try {
      final val = double.parse(value.toString());
      if (val < min) return min;
      if (max != null && val > max) return max;
      return val;
    } catch (e) {
      debugPrint('Invalid double value: $value');
      return min;
    }
  }

  static int _getInt(dynamic value, {int min = 0, int? max, int fallback = 0}) {
    try {
      final val = int.parse(value.toString());
      if (val < min) return min;
      if (max != null && val > max) return max;
      return val;
    } catch (e) {
      debugPrint('Invalid int value: $value');
      return fallback;
    }
  }
}
