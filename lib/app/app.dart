import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/deeplinks/screens/deeplink_home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepLink QR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const DeepLinkHomeScreen(),
    );
  }
}
