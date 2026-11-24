import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'presentation/auth/splash_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/register_screen.dart';
import 'presentation/auth/forgot_password_screen.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/room/room_detail_screen.dart';
import 'presentation/room/create_room_screen.dart';
import 'presentation/room/my_rooms_screen.dart';
import 'presentation/room/my_bookings_screen.dart';
import 'presentation/widgets/app_button_style.dart';
import 'core/guards/admin_guard.dart';
import 'domain/models/package_plan.dart';
import 'domain/models/room.dart';
import 'presentation/admin/admin_dashboard_screen.dart';
import 'presentation/package/packages_screen.dart';
import 'presentation/package/order_confirmation_screen.dart';
import 'presentation/package/payment_processing_screen.dart';
import 'presentation/package/payment_result_screen.dart';
import 'presentation/package/my_packages_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('vi', null);
  runApp(const RoomFinderApp());
}

class RoomFinderApp extends StatelessWidget {
  const RoomFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trọ Tốt | Hệ thống mua bán, cho thuê phòng trọ tại Hà Nội',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          primary: const Color(0xFF00897B),
          secondary: const Color(0xFF26A69A),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A2E),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppButtonStyle.primary(),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppButtonStyle.outlined(),
        ),
        textButtonTheme: TextButtonThemeData(
          style: AppButtonStyle.text(),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF00897B),
          foregroundColor: Colors.white,
          hoverColor: Color(0xFF00695C),
          hoverElevation: 8,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFF00897B).withAlpha(30);
              }
              return Colors.transparent;
            }),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/room-detail': (context) => const RoomDetailScreen(),
        '/create-room': (context) => const CreateRoomScreen(),
        '/my-rooms': (context) => const MyRoomsScreen(),
        '/my-bookings': (context) => const MyBookingsScreen(),
        '/admin': (context) => const AdminGuard(child: AdminDashboardScreen()),
        '/packages': (context) => const PackagesScreen(),
        '/my-packages': (context) => const MyPackagesScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/packages') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => PackagesScreen(
              preselectedRoomId: args?['preselectedRoomId'] as String?,
            ),
          );
        }
        if (settings.name == '/order-confirmation') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(
              package: args['package'] as PackagePlan,
              preselectedRoomId: args['preselectedRoomId'] as String?,
            ),
          );
        }
        if (settings.name == '/payment-processing') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => PaymentProcessingScreen(
              orderId: args['orderId'] as String,
              package: args['package'] as PackagePlan,
              room: args['room'] as Room,
              payUrl: args['payUrl'] as String?,
              qrCodeUrl: args['qrCodeUrl'] as String?,
              deeplink: args['deeplink'] as String?,
            ),
          );
        }
        if (settings.name == '/payment-result') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => PaymentResultScreen(
              isSuccess: args['isSuccess'] as bool? ?? false,
              orderId: args['orderId'] as String? ?? '',
              package: args['package'] as PackagePlan? ?? PackagePlan.defaultPlans.first,
              room: args['room'] as Room? ??
                  Room(
                    roomId: '',
                    ownerId: '',
                    title: 'Phòng trọ',
                    description: '',
                    price: 0,
                    area: 0,
                    address: '',
                    district: '',
                    images: [],
                    amenities: [],
                    roomType: '',
                    status: '',
                  ),
              paidAt: args['paidAt'] as DateTime?,
              expiresAt: args['expiresAt'] as DateTime?,
              transId: args['transId'] as String?,
              errorMessage: args['errorMessage'] as String?,
            ),
          );
        }
        return null;
      },
    );
  }
}
