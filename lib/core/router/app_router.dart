import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/firebase_providers.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/ui/register_page.dart';
import '../../features/home/ui/home_page.dart';
import '../../features/home/ui/scan_history_page.dart';
import '../../features/home/ui/scan_page.dart';
import '../../features/profile/ui/about_page.dart';
import '../../features/profile/ui/profile_page.dart';
import '../../features/splash/splash_page.dart';

// Route names as constants
class AppRoutes {
  static const splash  = '/';
  static const login   = '/login';
  static const register = '/register';
  static const home    = '/home';
  static const scan    = '/home/scan';
  static const history = '/home/history';
  static const about   = '/home/about';
  static const profile = '/home/profile';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final isSplash = state.matchedLocation == AppRoutes.splash;
      if (isSplash) return null; // always allow splash

      final isAuthenticated = authState.valueOrNull != null;
      final isLoading = authState.isLoading;

      if (isLoading) return null;

      final onAuthPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!isAuthenticated && !onAuthPage) return AppRoutes.login;
      if (isAuthenticated && onAuthPage) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'scan',
            name: 'scan',
            builder: (context, state) => ScanPage(
              initialImage: state.extra is XFile ? state.extra as XFile : null,
            ),
          ),
          GoRoute(
            path: 'history',
            name: 'history',
            builder: (context, state) => const ScanHistoryPage(),
          ),
          GoRoute(
            path: 'about',
            name: 'about',
            builder: (context, state) => const AboutPage(),
          ),
          GoRoute(
            path: 'profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.error}'),
          ],
        ),
      ),
    ),
  );
});
