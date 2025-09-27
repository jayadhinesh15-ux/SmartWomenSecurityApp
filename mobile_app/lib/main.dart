// mobile_app/lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

// ========= CONFIG - replace this AFTER you deploy backend =========
const String backendUrl = "https://smartwomensecurityapp.onrender.com"; // e.g. https://women-security-backend.onrender.com
// =================================================================

// Top-level background handler required by firebase_messaging
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // You can handle background messages here.
  if (message.notification != null) {
    // print to logs
    print('Background message: ${message.notification!.title} - ${message.notification!.body}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Women Security App',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? token;
  bool registered = false;
  String statusText = "";

  @override
  void initState() {
    super.initState();
    initFirebaseMessaging();
  }

  Future<void> initFirebaseMessaging() async {
    // Get device token
    try {
      String? t = await FirebaseMessaging.instance.getToken();
      setState(() {
        token = t;
      });
      print("FCM token: $token");
    } catch (e) {
      print("Error fetching token: $e");
    }

    // Show foreground messages as SnackBar
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? "Alert";
      final body = message.notification?.body ?? "";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$title — $body")),
        );
      }
    });

    // Optional: handle when app is opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Message opened app: ${message.messageId}");
    });
  }

  Future<void> registerContact() async {
    if (token == null) {
      setState(() => statusText = "No device token yet. Try again in a moment.");
      return;
    }
    try {
      final uri = Uri.parse('$backendUrl/register_contact');
      final res = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}));
      setState(() {
        statusText = 'Registered: ${res.statusCode}';
        registered = res.statusCode == 200;
      });
    } catch (e) {
      setState(() => statusText = 'Register failed: $e');
    }
  }

  Future<void> sendSOS() async {
    try {
      final uri = Uri.parse('$backendUrl/send_sos');
      final res = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'message': 'Emergency! Please help me!'}));
      setState(() {
        statusText = 'SOS sent: ${res.statusCode}';
      });
    } catch (e) {
      setState(() => statusText = 'Send SOS failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Women Security App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SelectableText('FCM token:\n${token ?? "loading..."}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: registerContact,
              child: const Text("Register as Contact (Father)"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: sendSOS,
              child: const Text("Send SOS (Woman)"),
            ),
            const SizedBox(height: 12),
            Text(statusText),
          ],
        ),
      ),
    );
  }
}
