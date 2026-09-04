import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/colors.dart';
import 'features/config/config_gate.dart';
import 'l10n/generated/app_localizations.dart';
import 'router.dart';

class OpenTransitApp extends ConsumerWidget {
  const OpenTransitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    final cityId = settings.cityId;
    final city = cityId == null ? null : ref.watch(cityProvider(cityId)).asData?.value;
    final seed = colorFromHex(city?.primaryColor, fallback: const Color(0xFF1565C0));

    return MaterialApp.router(
      title: 'OpenTransit',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) => ConfigGate(child: child ?? const SizedBox.shrink()),
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
