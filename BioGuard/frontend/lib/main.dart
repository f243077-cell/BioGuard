import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'screens/alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/report_screen.dart';
import 'services/fcm_service.dart';
import 'widgets/authenticated_app_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FcmService().initialize();
  runApp(const ProviderScope(child: BioGuardApp()));
}

class BioGuardApp extends ConsumerWidget {
  const BioGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    Widget home;
    switch (authState.status) {
      case AuthStatus.unknown:
        home = const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.unauthenticated:
        home = const LoginScreen();
      case AuthStatus.authenticated:
        home = const MainShell();
    }

    return MaterialApp(
      title: 'BioGuard',
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}

/// Bottom-nav shell switching between the live Dashboard and Alerts screens.
/// Bottom-nav shell switching between the live Dashboard and Alerts screens.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  static const _titles = ['Dashboard', 'Alerts', 'Reports'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AuthenticatedAppBar(title: _titles[_index]),
      body: IndexedStack(
        index: _index,
        children: [
          const DashboardScreen(),
          const AlertsScreen(),
          ReportScreen(isActive: _index == 2),
        ],
      ),
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
