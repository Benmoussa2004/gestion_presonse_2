import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/config/dev_flags.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/role_redirector.dart';
import '../features/classes/presentation/classes_screen.dart';
import '../features/sessions/presentation/sessions_screen.dart';
import '../features/attendance/presentation/attendance_screen.dart';
import '../features/attendance/presentation/scanner_screen.dart';
import '../features/stats/presentation/stats_screen.dart';
import '../features/users/presentation/users_screen.dart';
import '../features/students/presentation/schedule_screen.dart';

class AppRoutes {
  static const root = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const teacher = '/teacher';
  static const student = '/student';
  static const classes = '/classes';
  static const sessions = '/sessions';
  static const attendance = '/attendance';
  static const scanner = '/scanner';
  static const stats = '/stats';
  static const users = '/users';
  static const studentSchedule = '/student/schedule';
}

class AppRouter {
  static GoRouter build() {
    final String initial = _initialLocation();
    return GoRouter(
      initialLocation: initial,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.root,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: RoleRedirectorScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.signup,
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: AppRoutes.classes,
          builder: (context, state) => const ClassesScreen(),
        ),
        GoRoute(
          path: AppRoutes.sessions,
          builder: (context, state) => const SessionsScreen(),
        ),
        GoRoute(
          path: AppRoutes.attendance,
          builder: (context, state) => const AttendanceScreen(),
        ),
        GoRoute(
          path: AppRoutes.scanner,
          builder: (context, state) => const ScannerScreen(),
        ),
        GoRoute(
          path: AppRoutes.stats,
          builder: (context, state) => const StatsScreen(),
        ),
        GoRoute(
          path: AppRoutes.users,
          builder: (context, state) => const UsersScreen(),
        ),
        GoRoute(
          path: AppRoutes.studentSchedule,
          builder: (context, state) => const StudentScheduleScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body: Center(
          child: Text('Route not found: \'${state.uri}\''),
        ),
      ),
    );
  }

  static String _initialLocation() {
    if (DevFlags.hasForceRoute) {
      DevFlags.debugLog('FORCE_ROUTE=' + DevFlags.forceRoute);
      return DevFlags.forceRoute;
    }
    if (DevFlags.hasForceRole) {
      DevFlags.debugLog('FORCE_ROLE=' + DevFlags.forceRole);
      switch (DevFlags.forceRole) {
        case 'admin':
        case 'teacher':
          return AppRoutes.classes;
        case 'student':
          return AppRoutes.studentSchedule;
      }
    }
    return AppRoutes.root;
  }
}
