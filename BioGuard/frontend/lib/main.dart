import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/report_screen.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FcmService().initialize();
  runApp(const BioGuardApp());
}

class BioGuardApp extends StatelessWidget {
  const BioGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioGuard',
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}

/// Bottom-nav shell switching between the live Dashboard and Alerts screens.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [DashboardScreen(), AlertsScreen(), ReportScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF1B1035),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
