import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'data/content.dart';
import 'data/local_store.dart';
import 'data/user_data.dart';
import 'router.dart';
import 'services/backend.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString('assets/content/content.json');
  final content = ContentRepo.fromJsonString(raw);

  LocalStore store = DriftStore();
  try {
    await store.open();
  } catch (e) {
    debugPrint('local store: $e');
    store = MemoryStore();
    await store.open();
  }
  final user = UserData(store)..domainOf = content.domainOfTarget;
  await user.load();
  final backend = Backend();

  runApp(ProviderScope(
    overrides: [
      contentProvider.overrideWithValue(content),
      userProvider.overrideWith((ref) => user),
      backendProvider.overrideWith((ref) => backend),
    ],
    child: const LingoraApp(),
  ));

  // Sunucu bağlantısı arka planda kurulur; uygulama beklemeden çevrimdışı çalışır.
  await backend.init();
  final drafts = await backend.fetchShowDrafts();
  if (drafts != null) content.showDrafts = drafts;
  await backend.sync(user, pull: user.events.isEmpty && backend.account == AccountKind.email);
}

class LingoraApp extends ConsumerStatefulWidget {
  const LingoraApp({super.key});
  @override
  ConsumerState<LingoraApp> createState() => _LingoraAppState();
}

class _LingoraAppState extends ConsumerState<LingoraApp> {
  late final router = buildRouter(ref);

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(userProvider.select((u) => u.themeMode));
    return MaterialApp.router(
      title: 'Lingora',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Palette.light, Brightness.light),
      darkTheme: buildTheme(Palette.dark, Brightness.dark),
      themeMode: switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
