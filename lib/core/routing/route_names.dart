/// Rutas tipadas para las 22 pantallas de ENTRE NOS.
abstract final class RouteNames {
  // Gatekeeper & Auth
  static const String splash = '/splash';
  static const String setupGuide = '/setup-guide';
  static const String preview = '/preview';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String invitationRequest = '/invitation-request';
  static const String pendingApproval = '/pending-approval';
  static const String accessDenied = '/access-denied';

  // Navegación Inferior (5 Pestañas principales)
  static const String feed = '/feed';
  static const String moments = '/moments';
  static const String createHub = '/create';
  static const String chat = '/chat';
  static const String profile = '/profile';

  // Pantallas Secundarias del Círculo
  static const String createPost = '/create-post';
  static const String postDetail = '/post/:postId';
  static const String comments = '/comments/:postId';
  static const String createStory = '/create-story';
  static const String chatThread = '/chat/:conversationId';
  static const String createPoll = '/create-poll';
  static const String memories = '/memories';
  static const String capsules = '/capsules';
  static const String settings = '/settings';
  static const String adminPanel = '/admin';
}