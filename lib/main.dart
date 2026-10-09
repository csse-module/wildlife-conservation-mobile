import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/patrol_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'services/api_service.dart';
import 'features/operations/data/api_repositories.dart';
import 'features/operations/data/report_outbox.dart';
import 'features/operations/domain/repositories.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(api: context.read<ApiService>()),
        ),
        Provider<ParkRepository>(
          create: (context) => ApiParkRepository(
            context.read<ApiService>(),
            ownerId: () => context.read<AuthProvider>().user?.id,
          ),
        ),
        Provider<FieldReportRepository>(
          create: (context) =>
              ApiFieldReportRepository(context.read<ApiService>()),
        ),
        Provider<ReportingRepository>(
          create: (context) =>
              ApiReportingRepository(context.read<ApiService>()),
        ),
        Provider<AlertRepository>(
          create: (context) => ApiAlertRepository(context.read<ApiService>()),
        ),
        Provider<CameraRepository>(
          create: (context) => ApiCameraRepository(context.read<ApiService>()),
        ),
        Provider<PatrolManagementRepository>(
          create: (context) =>
              ApiPatrolManagementRepository(context.read<ApiService>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReportOutbox>(
          create: (context) => ReportOutbox(
            context.read<ApiService>(),
            PreferencesReportOutboxStore(),
          ),
          update: (context, auth, outbox) => outbox!..setUser(auth.user),
        ),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => PatrolProvider()),
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
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
