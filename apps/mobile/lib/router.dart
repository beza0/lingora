import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'ui/screens/assessment_screen.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/collection_screen.dart';
import 'ui/screens/explore_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/pack_screen.dart';
import 'ui/screens/phrasebook_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/screens/reading_screen.dart';
import 'ui/screens/scenario_screen.dart';
import 'ui/screens/session_screen.dart';
import 'ui/screens/target_screen.dart';
import 'ui/screens/writing_screen.dart';

GoRouter buildRouter(WidgetRef ref) {
  final user = ref.read(userProvider);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: user,
    redirect: (context, state) {
      final onboarding = state.matchedLocation.startsWith('/welcome');
      if (!user.onboarded && !onboarding) return '/welcome';
      if (user.onboarded && onboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => _Shell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
          GoRoute(path: '/chat', builder: (_, __) => const ChatListScreen()),
          GoRoute(path: '/collection', builder: (_, __) => const CollectionScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/session/:domain', builder: (_, s) => SessionScreen(domainId: s.pathParameters['domain']!)),
      GoRoute(path: '/assessment/:domain', builder: (_, s) => AssessmentScreen(domainId: s.pathParameters['domain']!)),
      GoRoute(path: '/writing/:id', builder: (_, s) => WritingScreen(taskId: s.pathParameters['id']!)),
      GoRoute(path: '/target/:id', builder: (_, s) => TargetScreen(targetId: s.pathParameters['id']!)),
      GoRoute(path: '/pack/:id', builder: (_, s) => PackScreen(packId: s.pathParameters['id']!)),
      GoRoute(path: '/reading/:id', builder: (_, s) => ReadingScreen(readingId: s.pathParameters['id']!)),
      GoRoute(path: '/scenario/:id', builder: (_, s) => ScenarioScreen(scenarioId: s.pathParameters['id']!)),
      GoRoute(path: '/phrasebook/:domain', builder: (_, s) => PhrasebookScreen(domainId: s.pathParameters['domain']!)),
      GoRoute(
        path: '/chat/:thread',
        builder: (_, s) => ChatScreen(
          threadId: s.pathParameters['thread'] == 'new' ? null : s.pathParameters['thread'],
          initialContext: s.extra as Map<String, Object?>?,
        ),
      ),
      GoRoute(path: '/auth', builder: (_, s) => AuthScreen(startWithLogin: s.uri.queryParameters['mode'] == 'login')),
      GoRoute(path: '/domains', builder: (_, __) => const DomainPickerScreen(editing: true)),
    ],
  );
}

class _Shell extends StatelessWidget {
  final String location;
  final Widget child;
  const _Shell({required this.location, required this.child});

  static const _tabs = ['/home', '/explore', '/chat', '/collection', '/profile'];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => location.startsWith(t)).clamp(0, _tabs.length - 1);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Bugün'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Keşfet'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Sor'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Koleksiyon'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
