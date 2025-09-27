import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shake/shake.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

const String BACKEND_ALERT_URL = "https://YOUR_RENDER_URL/send_alert";
const String BACKEND_REGISTER_CONTACT = "https://YOUR_RENDER_URL/register_contact";
const String BACKEND_CHECKIN = "https://YOUR_RENDER_URL/checkin_set";
const String USER_ID = "user1";

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(SmartSecurityApp());
}

class SmartSecurityApp extends StatefulWidget {
  @override
  _SmartSecurityAppState createState() => _SmartSecurityAppState();
}

class _SmartSecurityAppState extends State<SmartSecurityApp> {
  String _status = "Idle";
  late ShakeDetector _shakeDetector;
  Timer? _checkinTimer;
  int _checkinTimeoutSeconds = 0;
  String _fcmToken = "";

  @override
  void initState() {
    super.initState();
    _initLocationPermission();
    _initFCM();
    _shakeDetector = ShakeDetector.autoStart(onPhoneShake: () {
      _onShakeDetected();
    });
  }

  Future<void> _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    String? token = await messaging.getToken();
    if (token != null) {
      setState(() => _fcmToken = token);
      await _registerContactToken(token);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground message: ${message.notification?.title}");
    });
  }

  Future<void> _registerContactToken(String token) async {
    try {
      await http.post(
        Uri.parse(BACKEND_REGISTER_CONTACT),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": USER_ID, "contact_token": token}),
      );
    } catch (e) {
      print("register contact error: $e");
    }
  }

  Future<void> _initLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = "Enable location services");
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = "Location permissions permanently denied");
      return;
    }
  }

  Future<Position?> _getPosition() async {
    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("get position error: $e");
      return null;
    }
  }

  Future<void> _sendAlert(String reason) async {
    setState(() => _status = "Sending alert ($reason)...");
    Position? pos = await _getPosition();
    if (pos == null) {
      setState(() => _status = "Unable to get location");
      return;
    }
    var body = {"user_id": USER_ID, "latitude": pos.latitude, "longitude": pos.longitude, "reason": reason};
    try {
      await http.post(Uri.parse(BACKEND_ALERT_URL),
          headers: {"Content-Type": "application/json"}, body: json.encode(body));
      setState(() => _status = "Alert sent");
    } catch (e) {
      setState(() => _status = "Alert error: $e");
    }
  }

  void _onShakeDetected() {
    _sendAlert("shake");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Shake detected — SOS sent")));
  }

  void _startCheckinTimer(int seconds) {
    if (seconds <= 0) return;
    _checkinTimer?.cancel();
    _checkinTimeoutSeconds = seconds;
    _checkinTimer = Timer(Duration(seconds: seconds), () {
      _sendAlert("checkin_timeout");
      setState(() => _checkinTimeoutSeconds = 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Check-in timeout — SOS sent")));
    });
    setState(() {});
  }

  void _cancelCheckinTimer() {
    _checkinTimer?.cancel();
    _checkinTimeoutSeconds = 0;
    setState(() {});
  }

  Future<void> _manualCheckIn() async {
    try {
      await http.post(Uri.parse(BACKEND_CHECKIN),
          headers: {"Content-Type": "application/json"}, body: json.encode({"user_id": USER_ID}));
      _cancelCheckinTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Checked in")));
    } catch (e) {
      print("checkin error: $e");
    }
  }

  @override
  void dispose() {
    _shakeDetector.stopListening();
    _checkinTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Women Security',
      home: Scaffold(
        appBar: AppBar(title: Text('Smart Women Security')),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Spacer(),
              Text("Status: $_status"),
              SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () => _sendAlert("manual"), child: Text("Manual SOS")),
              SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () => _startCheckinTimer(60),
                  child: Text("Start 1-min Check-in Timer")),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _manualCheckIn, child: Text("Check-in Now")),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
