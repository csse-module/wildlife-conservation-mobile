import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/incident_provider.dart';
import 'providers/patrol_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => PatrolProvider()),
        ChangeNotifierProxyProvider<AuthProvider, IncidentProvider>(
          create: (context) => IncidentProvider(Provider.of<AuthProvider>(context, listen: false)),
          update: (context, auth, previous) => previous ?? IncidentProvider(auth),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wildlife Conservation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppConstants.primaryGreen,
        scaffoldBackgroundColor: AppConstants.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryGreen),
        useMaterial3: true,
        fontFamily: 'Roboto', // Modern standard font
      ),
      home: const SplashScreen(),
    );
  }
}
