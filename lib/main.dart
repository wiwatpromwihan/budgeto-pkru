import 'package:budgeto/budget.dart';
import 'package:budgeto/screens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BudgetoApp());
}

class BudgetoApp extends StatelessWidget {
  const BudgetoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF15263A);
    return MaterialApp(
      title: 'Budgeto PKRU',
      debugShowCheckedModeBanner: false,
      locale: const Locale('th', 'TH'),
      supportedLocales: const [Locale('th', 'TH')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087F77),
          primary: const Color(0xFF087F77),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F6F8),
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Arial',
          bodyColor: ink,
          displayColor: ink,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('ตรวจสอบสถานะบัญชีไม่สำเร็จ')),
            );
          }
          final user = snapshot.data;
          return user == null
              ? const AuthScreen()
              : DashboardScreen(
                  key: ValueKey(user.uid),
                  user: user,
                  store: BudgetStore(),
                );
        },
      ),
    );
  }
}
