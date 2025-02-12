import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CompostMonitorScreen(),
    );
  }
}

class CompostMonitorScreen extends StatefulWidget {
  @override
  CompostMonitorScreenState createState() => CompostMonitorScreenState();
}

class CompostMonitorScreenState extends State<CompostMonitorScreen> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("IOT2");

  double humidity = 0.0;
  double temperature = 0.0;
  int compostState = 0;
  double composeLevel = 0.0;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void fetchData() {
    dbRef.child("humidity").onValue.listen((event) {
      setState(() {
        humidity = (event.snapshot.value as num?)?.toDouble() ?? 0.0;
      });
    });

    dbRef.child("temperature").onValue.listen((event) {
      setState(() {
        temperature = (event.snapshot.value as num?)?.toDouble() ?? 0.0;
      });
    });

    dbRef.child("compost_state").onValue.listen((event) {
      setState(() {
        compostState = (event.snapshot.value as int?) ?? 0;
      });
    });

    dbRef.child("compose_level").onValue.listen((event) {
      setState(() {
        composeLevel = (event.snapshot.value as num?)?.toDouble() ?? 0.0;
      });
    });
  }

  void toggleCompost() {
    // Toggle "compost_state" between 0 and 1
    int newCompostState = compostState == 0 ? 1 : 0;
    dbRef.child("compost_state").set(newCompostState);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Compost Monitoring")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top Row: Humidity & Temperature
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildSensorValue("Humidity", "$humidity%"),
                buildSensorValue("Temperature", "$temperature°C"),
              ],
            ),
            SizedBox(height: 40),

            // Middle Section: Compost Level
            Column(
              children: [
                Text("Compost Level",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: composeLevel /
                            100, // reflect the value of "compose_level"
                        strokeWidth: 10,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    Text("${composeLevel.toStringAsFixed(0)}%",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 40),

            // Button to Retrieve Compost (Toggle compost_state)
            ElevatedButton(
              onPressed: toggleCompost,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text(
                  compostState == 1 ? "Compost Retrieved" : "Retrieve Compost"),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for Humidity and Temperature Display
  Widget buildSensorValue(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
      ],
    );
  }
}
