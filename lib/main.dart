import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'providers/vault_provider.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/screens/vault_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IronKeyMobileApp());
}

class IronKeyMobileApp extends StatefulWidget {
  const IronKeyMobileApp({super.key});

  @override
  State<IronKeyMobileApp> createState() => _IronKeyMobileAppState();
}

class _IronKeyMobileAppState extends State<IronKeyMobileApp> {
  late final VaultProvider _vaultProvider;

  @override
  void initState() {
    super.initState();
    _vaultProvider = VaultProvider();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vaultProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'IronKey Mobile',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: _vaultProvider.isUnlocked
              ? VaultScreen(vaultProvider: _vaultProvider)
              : LockScreen(
                  vaultProvider: _vaultProvider,
                  onUnlocked: () => setState(() {}),
                ),
        );
      },
    );
  }
}
