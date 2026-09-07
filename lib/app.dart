import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/analytics/analytics.dart';
import 'core/analytics/analytics_event.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/colors.dart';
import 'core/utils/route_alert_watcher.dart';
import 'core/widgets/connectivity_bar.dart';
import 'features/config/config_gate.dart';
import 'l10n/generated/app_localizations.dart';
import 'router.dart';

class OpenTransitApp extends ConsumerStatefulWidget {
  const OpenTransitApp({super.key});

  @override
  ConsumerState<OpenTransitApp> createState() => _OpenTransitAppState();
}

class _OpenTransitAppState extends ConsumerState<OpenTransitApp>
    with WidgetsBindingObserver {
  String? _lastScreen;
  GoRouter? _observed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // `app_open` once per cold start; the entry is refined by the first
    // screen view (deep links land on a non-home route).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = ref.read(routerProvider);
      final loc = router.routerDelegate.currentConfiguration.uri.toString();
      final entry =
          loc == '/' ||
              screenNameFor(loc) == 'home' ||
              screenNameFor(loc) == 'cities'
          ? 'home'
          : 'deeplink';
      ref.read(analyticsProvider).track(Ev.appOpen, {
        'coldStart': true,
        'entry': entry,
      });
      // Saved-route alerts: local notifications only, armed per route.
      ref.read(routeAlertWatcherProvider).start();
    });
  }

  @override
  void dispose() {
    _observed?.routerDelegate.removeListener(_onRoute);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(analyticsProvider).onAppBackground();
    }
    if (state == AppLifecycleState.resumed) {
      // Coming back is the cheapest moment to look for route alerts.
      ref.read(routeAlertWatcherProvider).check();
    }
  }

  void _observe(GoRouter router) {
    if (identical(_observed, router)) return;
    _observed?.routerDelegate.removeListener(_onRoute);
    _observed = router..routerDelegate.addListener(_onRoute);
  }

  void _onRoute() {
    final router = _observed;
    if (router == null) return;
    final name = screenNameFor(
      router.routerDelegate.currentConfiguration.uri.toString(),
    );
    if (name == null || name == _lastScreen) return;
    _lastScreen = name;
    ref.read(analyticsProvider).track(Ev.screenView, {'screen': name});
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    _observe(router);
    final cityId = settings.cityId;
    final city = cityId == null
        ? null
        : ref.watch(cityProvider(cityId)).asData?.value;
    final seed = colorFromHex(
      city?.primaryColor,
      fallback: const Color(0xFF1565C0),
    );

    return MaterialApp.router(
      title: 'OpenTransit',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        // The watcher has no BuildContext of its own; give it the localised
        // notification title now that one exists.
        final l10n = AppLocalizations.of(context);
        ref.read(routeAlertWatcherProvider).titleBuilder =
            (route) => l10n.routeAlertNotificationTitle(route);
        return ConfigGate(
          child: ConnectivityBar(child: child ?? const SizedBox.shrink()),
        );
      },
      theme: buildTheme(seed, Brightness.light),
      darkTheme: buildTheme(seed, Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (device, supported) {
        if (device == null) return const Locale('es');
        for (final s in supported) {
          if (s.languageCode == device.languageCode) return s;
        }
        return const Locale('es');
      },
    );
  }
}
