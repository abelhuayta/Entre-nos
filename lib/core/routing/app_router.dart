import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/session_gate_provider.dart';
import '../../features/capsules/presentation/capsules_screen.dart';
import '../../features/capsules/presentation/create_capsule_screen.dart';
import '../../features/chat/presentation/chat_inbox_screen.dart';
import '../../features/chat/presentation/chat_room_screen.dart';
import '../../features/design_system/design_system_preview_screen.dart';
import '../../features/home/presentation/create_hub_screen.dart';
import '../../features/home/presentation/main_shell_screen.dart';
import '../../features/invitations/presentation/access_denied_screen.dart';
import '../../features/invitations/presentation/admin_panel_screen.dart';
import '../../features/invitations/presentation/invitation_request_screen.dart';
import '../../features/invitations/presentation/pending_approval_screen.dart';
import '../../features/media/presentation/media_viewer_screen.dart';
import '../../features/moments/presentation/create_moment_screen.dart';
import '../../features/moments/presentation/moment_viewer_screen.dart';
import '../../features/moments/presentation/moments_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/posts/presentation/comments_screen.dart';
import '../../features/posts/presentation/create_post_screen.dart';
import '../../features/posts/presentation/feed_screen.dart';
import '../../features/posts/presentation/post_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../widgets/env_setup_banner_screen.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final gateNotifier = ref.read(sessionGateProvider.notifier);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: gateNotifier,
    redirect: (context, state) {
      final gate = ref.read(sessionGateProvider);
      final loc = state.matchedLocation;

      if (loc == RouteNames.preview) return null;

      if (gate.status == GateStatus.unconfigured) {
        return loc == RouteNames.setupGuide ? null : RouteNames.setupGuide;
      }

      if (gate.status == GateStatus.loading) {
        return loc == RouteNames.splash ? null : RouteNames.splash;
      }

      final publicAuthRoutes = {
        RouteNames.welcome,
        RouteNames.login,
        RouteNames.register,
        RouteNames.forgotPassword,
      };

      if (gate.status == GateStatus.unauthenticated) {
        return publicAuthRoutes.contains(loc) ? null : RouteNames.welcome;
      }

      if (gate.status == GateStatus.needsInvitation) {
        return loc == RouteNames.invitationRequest
            ? null
            : RouteNames.invitationRequest;
      }

      if (gate.status == GateStatus.pendingApproval) {
        return loc == RouteNames.pendingApproval
            ? null
            : RouteNames.pendingApproval;
      }

      if (gate.status == GateStatus.blockedOrRemoved) {
        return loc == RouteNames.accessDenied ? null : RouteNames.accessDenied;
      }

      final gateRoutes = {
        RouteNames.splash,
        RouteNames.setupGuide,
        RouteNames.welcome,
        RouteNames.login,
        RouteNames.register,
        RouteNames.invitationRequest,
        RouteNames.pendingApproval,
        RouteNames.accessDenied,
      };

      if (gate.status == GateStatus.approved && gateRoutes.contains(loc)) {
        return RouteNames.feed;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.setupGuide,
        builder: (context, state) => const EnvSetupBannerScreen(),
      ),
      GoRoute(
        path: RouteNames.preview,
        builder: (context, state) => const DesignSystemPreviewScreen(),
      ),
      GoRoute(
        path: RouteNames.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.invitationRequest,
        builder: (context, state) => const InvitationRequestScreen(),
      ),
      GoRoute(
        path: RouteNames.pendingApproval,
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: RouteNames.accessDenied,
        builder: (context, state) => const AccessDeniedScreen(),
      ),
      GoRoute(
        path: RouteNames.adminPanel,
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        path: RouteNames.createPost,
        builder: (context, state) {
          final isPoll = state.uri.queryParameters['poll'] == '1';
          return CreatePostScreen(startAsPoll: isPoll);
        },
      ),
      GoRoute(
        path: RouteNames.postDetail,
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return PostDetailScreen(postId: postId);
        },
      ),
      GoRoute(
        path: RouteNames.comments,
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return CommentsScreen(postId: postId);
        },
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return ChatRoomScreen(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: '/create-moment',
        builder: (context, state) => const CreateMomentScreen(),
      ),
      GoRoute(
        path: '/moment-viewer',
        builder: (context, state) {
          final args = state.extra as MomentViewerArgs;
          return MomentViewerScreen(args: args);
        },
      ),
      GoRoute(
        path: '/capsules',
        builder: (context, state) => const CapsulesScreen(),
      ),
      GoRoute(
        path: '/create-capsule',
        builder: (context, state) => const CreateCapsuleScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/media-viewer',
        builder: (context, state) {
          final args = state.extra as MediaViewerArgs;
          return MediaViewerScreen(args: args);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.feed,
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.moments,
                builder: (context, state) => const MomentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.createHub,
                builder: (context, state) => const CreateHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.chat,
                builder: (context, state) => const ChatInboxScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});