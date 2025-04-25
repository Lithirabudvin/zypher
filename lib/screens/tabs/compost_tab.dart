import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;

class CompostTab extends StatefulWidget {
  final String deviceId;

  const CompostTab({Key? key, required this.deviceId}) : super(key: key);

  @override
  _CompostTabState createState() => _CompostTabState();
}

class _CompostTabState extends State<CompostTab> {
  double _compostLevel = 0.0;
  bool _isRetrieving = false;
  bool _isLoading = true;
  late DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instance.ref('devices/${widget.deviceId}');
    _setupListeners();
  }

  void _setupListeners() {
    _dbRef.onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Note: compost_state (config for retrieval) doesn't need to be displayed here,
        // but we do need the compost level from sensor_data.

        double currentCompostLevel = 0.0;
        if (data['sensor_data'] != null) {
          final sensorData =
              Map<String, dynamic>.from(data['sensor_data'] as Map);
          currentCompostLevel = double.tryParse(
                  sensorData['compose_level']?.toString() ?? '0.0') ??
              0.0;
        }

        if (mounted) {
          setState(() {
            _compostLevel = currentCompostLevel;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error processing device data in CompostTab: $e");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _toggleCompostRetrieval() async {
    setState(() => _isRetrieving = true);
    try {
      await _dbRef.child('config').update({
        'compost_state': 1,
      });

      // Wait for 2 seconds to simulate the retrieval process
      await Future.delayed(Duration(seconds: 2));

      // Reset the state
      await _dbRef.child('config').update({
        'compost_state': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compost retrieved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to retrieve compost'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRetrieving = false);
      }
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compost Level',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 24),
                    Container(
                      height: 250,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              height: 210 * (_compostLevel / 100),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.compost,
                                  size: 64,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 20),
                                Text(
                                  '${_compostLevel.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Current Level',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                      'Compost Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.recycling,
                            size: 48,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed:
                                _isRetrieving ? null : _toggleCompostRetrieval,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size(double.infinity, 50),
                            ),
                            child: _isRetrieving
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Retrieving...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.recycling),
                                      SizedBox(width: 12),
                                      Text(
                                        'Retrieve Compost',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Add more space at the bottom for better scrolling
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class CompostLevelPainter extends CustomPainter {
  final double level;
  final Color backgroundColor;
  final Color progressColor;

  CompostLevelPainter({
    required this.level,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 20.0;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    // Draw progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2, // Start from top
      2 * math.pi * (level / 100), // Convert percentage to radians
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CompostLevelPainter oldDelegate) {
    return oldDelegate.level != level;
  }
}
