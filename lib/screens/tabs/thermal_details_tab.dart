import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ThermalDetailsTab extends StatefulWidget {
  final String deviceId;

  const ThermalDetailsTab({Key? key, required this.deviceId}) : super(key: key);

  @override
  _ThermalDetailsTabState createState() => _ThermalDetailsTabState();
}

class _ThermalDetailsTabState extends State<ThermalDetailsTab> {
  bool _isLoading = true;
  bool _isFlowRateManual = false;
  int _selectedFrequencyStep = 2; // Default to middle step
  late DatabaseReference _dbRef;
  Timer? _debounceTimer;
  File? _thermalImage;
  final ImagePicker _picker = ImagePicker();

  // Frequency steps configuration
  final List<Map<String, dynamic>> _frequencySteps = [
    {
      'label': 'Very Low',
      'value': 1,
      'interval': 60,
      'color': Colors.blue.value
    }, // 1 minute
    {
      'label': 'Low',
      'value': 2,
      'interval': 30,
      'color': Colors.lightBlue.value
    }, // 30 seconds
    {
      'label': 'Medium',
      'value': 3,
      'interval': 15,
      'color': Colors.green.value
    }, // 15 seconds
    {
      'label': 'High',
      'value': 4,
      'interval': 5,
      'color': Colors.orange.value
    }, // 5 seconds
    {
      'label': 'Very High',
      'value': 5,
      'interval': 1,
      'color': Colors.red.value
    }, // 1 second
  ];

  Color _getStepColor(int value) {
    final step = _frequencySteps.firstWhere(
      (step) => step['value'] == value,
      orElse: () => {'color': Colors.green.value},
    );
    return Color(step['color'] as int);
  }

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
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        bool isFlowRateManual = false;
        int frequencyStep = 2;

        if (data['config'] != null) {
          final config = Map<String, dynamic>.from(data['config'] as Map);
          isFlowRateManual = (config['flow_rate_mode'] ?? 0) == 1;
          frequencyStep = (config['flow_rate_frequency'] ?? 2).toInt();
        }

        if (mounted) {
          setState(() {
            _isFlowRateManual = isFlowRateManual;
            _selectedFrequencyStep = frequencyStep;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error processing device data in ThermalDetailsTab: $e");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _toggleFlowRateMode(bool isManual) async {
    try {
      await _dbRef.child('devices/${widget.deviceId}/config').update({
        'flow_rate_mode': isManual ? 1 : 0,
      });
      setState(() => _isFlowRateManual = isManual);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update flow rate mode'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateFrequencyStep(int step) async {
    setState(() => _selectedFrequencyStep = step);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _dbRef.child('devices/${widget.deviceId}/config').update({
          'flow_rate_frequency': step,
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update frequency step'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  Future<void> _pickThermalImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _thermalImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTimeGraph(int interval, Color color) {
    // Generate sample data points for the graph
    final List<FlSpot> spots = List.generate(
      10,
      (index) => FlSpot(
        index.toDouble(),
        (interval * (index + 1)).toDouble(),
      ),
    );

    // Calculate gradient colors based on the base color
    final Color startColor = color.withOpacity(0.3);
    final Color endColor = color.withOpacity(0.8);

    return Container(
      height: 150,
      padding: EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}s',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [startColor, endColor],
                ),
              ),
            ),
          ],
          minX: 0,
          maxX: 9,
          minY: 0,
          maxY: interval * 10,
        ),
      ),
    );
  }

  Widget _buildFrequencyStepButton(Map<String, dynamic> step) {
    final bool isSelected = step['value'] == _selectedFrequencyStep;
    final Color color = _getStepColor(step['value']);
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isSelected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => _updateFrequencyStep(step['value']),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step['label'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${step['interval']}s',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thermal Image',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/thermal_image.png',
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.thermostat,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Thermal image not found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
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
                      'Flow Rate Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        'Flow Rate Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _isFlowRateManual ? 'Manual Mode' : 'Auto Mode',
                        style: TextStyle(
                          color: _isFlowRateManual ? Colors.green : Colors.grey,
                        ),
                      ),
                      value: _isFlowRateManual,
                      onChanged: _toggleFlowRateMode,
                      activeColor: Colors.green,
                    ),
                    if (_isFlowRateManual) ...[
                      Divider(),
                      Text(
                        'Frequency Steps',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: _frequencySteps
                            .map(_buildFrequencyStepButton)
                            .toList(),
                      ),
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Time Graph for ${_frequencySteps[_selectedFrequencyStep - 1]['label']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            _buildTimeGraph(
                              _frequencySteps[_selectedFrequencyStep - 1]
                                  ['interval'],
                              _getStepColor(_selectedFrequencyStep),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
