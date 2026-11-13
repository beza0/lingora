import 'dart:ui' show PlatformDispatcher;

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
import 'services/telemetry.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Yakalanmayan hatalar anonim olarak kaydedilir (Telemetry, kişisel veri göndermez)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Telemetry.instance.error(details.exception, details.stack, type: 'flutter:${details.exception.runtimeType}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Telemetry.instance.error(error, stack);
    return true;
  };
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
  await Telemetry.instance.init(store, usage: user.usageStats);
  user.addListener(() => Telemetry.instance.usageEnabled = user.usageStats);
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
  backend.attach(user);
  await backend.init();
  await backend.finishPendingMerge(user);
  Telemetry.instance.event('app_open', {'account': backend.account.name, 'domains': user.activeDomains.length});
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
  void initState() {
    super.initState();
    router.routeInformationProvider.addListener(_onRoute);
    _onRoute();
  }

  void _onRoute() => Telemetry.instance.screen(router.routeInformationProvider.value.uri.path);

  @override
  void dispose() {
    router.routeInformationProvider.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(userProvider.select((u) => u.themeMode));
    return MaterialApp.router(
      title: 'Lingora',
      debugShowCheckedModeBanner: false,
      // Sistem yazı boyutuna uyulur; düzen bozulmasın diye en fazla 1,6 kat
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.6)), child: child!);
      },
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
