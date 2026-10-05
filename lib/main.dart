import 'package:flutter/material.dart';

import 'config/database/database_connection.dart';
import 'config/theme/app_theme.dart';
import 'features/backup/backup_scheduler.dart';
import 'features/backup/data/backup_service.dart';
import 'features/backup/presentation/screen/restore_backup_screen.dart';
import 'features/receipt_settings/data/repository/receipt_settings_repository.dart';
import 'features/login/presentation/provider/login_provider.dart';
import 'features/login/presentation/screen/login_screen.dart';
import 'features/shell/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to open the PostgreSQL connection before the app starts, but don't let
  // a connection failure kill the app — the login screen and each feature
  // surface database errors on their own, and the connection is retried lazily.
  try {
    await Database.instance.open();
    // Load the receipt header / field toggles so printed receipts use them
    // even before the settings screen is opened. Best-effort — never throws.
    await preloadReceiptSettings();
    // Arm the 6-hourly Supabase backup (no-op until it is configured).
    await BackupScheduler.instance.start();
  } catch (e, s) {
    debugPrint('Database.open() failed at startup: $e\n$s');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// On a brand-new install (no data, no users) first offers to restore the
/// cloud backup; then shows the login screen until a user signs in, then the
/// home page.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LoginProvider _auth = LoginProvider();

  /// `null` while checking; true → show [RestoreBackupScreen] first.
  bool? _offerRestore;

  @override
  void initState() {
    super.initState();
    _auth.restore();
    _checkFreshInstall();
  }

  Future<void> _checkFreshInstall() async {
    var fresh = false;
    try {
      // Only the local DB is read here; the credentials are irrelevant.
      fresh = await BackupService(supabaseUrl: '', supabaseKey: '')
          .isFreshInstall();
    } catch (e) {
      // DB offline etc. — fall through to the login screen, which reports it.
      debugPrint('AuthGate: fresh-install check failed: $e');
    }
    if (mounted) setState(() => _offerRestore = fresh);
  }

  Future<void> _onRestoreDone(bool restored) async {
    // The shop header came back with the data — reload it for receipts.
    if (restored) await preloadReceiptSettings();
    if (mounted) setState(() => _offerRestore = false);
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        if (_auth.restoring || _offerRestore == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_offerRestore! && !_auth.isLoggedIn) {
          return RestoreBackupScreen(onDone: _onRestoreDone);
        }
        if (!_auth.isLoggedIn) {
          return LoginScreen(provider: _auth, onLoggedIn: (_) {});
        }
        return HomeShell(auth: _auth);
      },
    );
  }
}
