import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/logs_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Ensure there is a signed-in user (anonymous auth for per-device logs)
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } catch (e) {
      // If anonymous auth fails, log but continue
      debugPrint('Firebase anonymous auth failed: $e');
    }
  } catch (e) {
    // If Firebase initialization fails, log but continue
    // The app can still run without Firebase for offline features
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Scanner',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Use GlobalKeys to access state of screens that need refreshing
  final GlobalKey<AnalyticsScreenState> _analyticsKey = GlobalKey<AnalyticsScreenState>();
  final GlobalKey<LogsScreenState> _logsKey = GlobalKey<LogsScreenState>();

  List<Widget> get _screens => [
    const HomeScreen(),
    const ScanScreen(),
    AnalyticsScreen(key: _analyticsKey),
    LogsScreen(key: _logsKey),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppTheme.chocolate.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // Only refresh if coming from scan screen (index 1)
            // This prevents unnecessary reloads when just switching tabs
            if (index == 2 && _currentIndex == 1) {
              // Coming from scan screen, refresh analytics
              _analyticsKey.currentState?.refresh();
            }
            if (index == 3 && _currentIndex == 1) {
              // Coming from scan screen, refresh logs
              _logsKey.currentState?.refresh();
            }
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.chocolate,
          selectedItemColor: AppTheme.tan,
          unselectedItemColor: Colors.white70,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Logs',
            ),
          ],
        ),
      ),
    );
  }
}
