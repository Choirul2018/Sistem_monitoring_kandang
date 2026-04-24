import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/audit/presentation/audit_list_screen.dart';
import '../features/audit/presentation/audit_detail_screen.dart';
import '../features/audit/presentation/audit_part_screen.dart';
import '../features/audit/presentation/camera_capture_screen.dart';
import '../features/audit/presentation/audit_summary_screen.dart';
import '../features/audit/presentation/signature_screen.dart';
import '../features/audit/presentation/livestock_sampling_screen.dart';
import '../features/location/presentation/location_list_screen.dart';
import '../features/location/presentation/location_map_screen.dart';
import '../features/report/presentation/report_screen.dart';
import '../features/report/presentation/report_preview_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = authState.valueOrNull != null;
      final isLoginRoute = state.uri.path == '/login';

      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && isLoginRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const AuditListScreen(),
      ),
      GoRoute(
        path: '/locations',
        builder: (context, state) => const LocationListScreen(),
      ),
      GoRoute(
        path: '/location-map/:id',
        builder: (context, state) => LocationMapScreen(
          locationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const AuditListScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: '/report/:id',
        builder: (context, state) => ReportPreviewScreen(
          auditId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/audit/:id',
        builder: (context, state) => AuditDetailScreen(
          auditId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/audit/:id/part/:index',
        builder: (context, state) => AuditPartScreen(
          auditId: state.pathParameters['id']!,
          partIndex: int.parse(state.pathParameters['index']!),
        ),
      ),
      GoRoute(
        path: '/audit/:id/camera/:index',
        builder: (context, state) => CameraCaptureScreen(
          auditId: state.pathParameters['id']!,
          partIndex: int.parse(state.pathParameters['index']!),
        ),
      ),
      GoRoute(
        path: '/audit/:id/summary',
        builder: (context, state) => AuditSummaryScreen(
          auditId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/audit/:id/signature',
        builder: (context, state) => SignatureScreen(
          auditId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/audit/:id/livestock',
        builder: (context, state) => LivestockSamplingScreen(
          auditId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
