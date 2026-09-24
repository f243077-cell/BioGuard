import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/report_screen.dart';
import 'services/fcm_service.dart';
import 'widgets/authenticated_app_bar.dart';
import 'widgets/glass.dart';
import 'widgets/glass_nav_bar.dart';

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
        home = const Scaffold(
          body: GlassBackground(
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      case AuthStatus.unauthenticated:
        home = const LoginScreen();
      case AuthStatus.authenticated:
        home = const MainShell();
    }

    return MaterialApp(
      title: 'BioGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: home,
    );
  }
}

/// Bottom-nav shell switching between the live Dashboard, Alerts and
/// Reports screens. The glass app bar and nav bar float over a shared
/// background; each page scrolls beneath them.
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
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AuthenticatedAppBar(title: _titles[_index]),
      body: GlassBackground(
        child: IndexedStack(
          index: _index,
          children: [
            const DashboardScreen(),
            const AlertsScreen(),
            ReportScreen(isActive: _index == 2),
          ],
        ),
      ),
      bottomNavigationBar: GlassNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          GlassNavItem(icon: Icons.space_dashboard_rounded, label: 'Dashboard'),
          GlassNavItem(icon: Icons.notifications_rounded, label: 'Alerts'),
          GlassNavItem(icon: Icons.picture_as_pdf_rounded, label: 'Reports'),
        ],
      ),
    );
  }
}
