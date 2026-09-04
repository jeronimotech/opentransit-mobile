import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'OpenTransit'**
  String get appTitle;

  /// No description provided for @chooseCity.
  ///
  /// In es, this message translates to:
  /// **'Elige tu ciudad'**
  String get chooseCity;

  /// No description provided for @chooseCitySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Planea viajes en transporte público con datos abiertos y en tiempo real.'**
  String get chooseCitySubtitle;

  /// No description provided for @searchPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'¿A dónde vas?'**
  String get searchPlaceholder;

  /// No description provided for @planTrip.
  ///
  /// In es, this message translates to:
  /// **'Planear viaje'**
  String get planTrip;

  /// No description provided for @fromLabel.
  ///
  /// In es, this message translates to:
  /// **'Origen'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In es, this message translates to:
  /// **'Destino'**
  String get toLabel;

  /// No description provided for @myLocation.
  ///
  /// In es, this message translates to:
  /// **'Mi ubicación'**
  String get myLocation;

  /// No description provided for @chooseOnMap.
  ///
  /// In es, this message translates to:
  /// **'Elegir en el mapa'**
  String get chooseOnMap;

  /// No description provided for @departAt.
  ///
  /// In es, this message translates to:
  /// **'Salir a las'**
  String get departAt;

  /// No description provided for @arriveBy.
  ///
  /// In es, this message translates to:
  /// **'Llegar antes de'**
  String get arriveBy;

  /// No description provided for @now.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get now;

  /// No description provided for @wheelchair.
  ///
  /// In es, this message translates to:
  /// **'Accesible en silla de ruedas'**
  String get wheelchair;

  /// No description provided for @modes.
  ///
  /// In es, this message translates to:
  /// **'Modos'**
  String get modes;

  /// No description provided for @searchAction.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get searchAction;

  /// No description provided for @results.
  ///
  /// In es, this message translates to:
  /// **'Resultados'**
  String get results;

  /// No description provided for @noItineraries.
  ///
  /// In es, this message translates to:
  /// **'No encontramos itinerarios para este viaje. Prueba otro horario o amplía la distancia a pie.'**
  String get noItineraries;

  /// No description provided for @transfersCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin transbordos} =1{1 transbordo} other{{count} transbordos}}'**
  String transfersCount(int count);

  /// No description provided for @walkDistance.
  ///
  /// In es, this message translates to:
  /// **'{meters} m a pie'**
  String walkDistance(int meters);

  /// No description provided for @itinerary.
  ///
  /// In es, this message translates to:
  /// **'Itinerario'**
  String get itinerary;

  /// No description provided for @departures.
  ///
  /// In es, this message translates to:
  /// **'Próximas salidas'**
  String get departures;

  /// No description provided for @noDepartures.
  ///
  /// In es, this message translates to:
  /// **'Sin salidas programadas en la próxima hora.'**
  String get noDepartures;

  /// No description provided for @realtime.
  ///
  /// In es, this message translates to:
  /// **'En vivo'**
  String get realtime;

  /// No description provided for @scheduled.
  ///
  /// In es, this message translates to:
  /// **'Programado'**
  String get scheduled;

  /// No description provided for @canceled.
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get canceled;

  /// No description provided for @delayedBy.
  ///
  /// In es, this message translates to:
  /// **'Retraso de {minutes} min'**
  String delayedBy(int minutes);

  /// No description provided for @earlyBy.
  ///
  /// In es, this message translates to:
  /// **'Adelantado {minutes} min'**
  String earlyBy(int minutes);

  /// No description provided for @onTime.
  ///
  /// In es, this message translates to:
  /// **'A tiempo'**
  String get onTime;

  /// No description provided for @alerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get alerts;

  /// No description provided for @noAlerts.
  ///
  /// In es, this message translates to:
  /// **'No hay alertas activas.'**
  String get noAlerts;

  /// No description provided for @favorites.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get favorites;

  /// No description provided for @noFavorites.
  ///
  /// In es, this message translates to:
  /// **'Guarda paradas, rutas y lugares para tenerlos a la mano.'**
  String get noFavorites;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @city.
  ///
  /// In es, this message translates to:
  /// **'Ciudad'**
  String get city;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @accessibility.
  ///
  /// In es, this message translates to:
  /// **'Accesibilidad'**
  String get accessibility;

  /// No description provided for @wheelchairPref.
  ///
  /// In es, this message translates to:
  /// **'Preferir rutas accesibles'**
  String get wheelchairPref;

  /// No description provided for @liveVehicles.
  ///
  /// In es, this message translates to:
  /// **'Vehículos en vivo'**
  String get liveVehicles;

  /// No description provided for @nearbyStops.
  ///
  /// In es, this message translates to:
  /// **'Paradas cercanas'**
  String get nearbyStops;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @errorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal. Revisa tu conexión e inténtalo de nuevo.'**
  String get errorGeneric;

  /// No description provided for @errorOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión con el servidor.'**
  String get errorOffline;

  /// No description provided for @routes.
  ///
  /// In es, this message translates to:
  /// **'Rutas'**
  String get routes;

  /// No description provided for @stops.
  ///
  /// In es, this message translates to:
  /// **'Paradas'**
  String get stops;

  /// No description provided for @stop.
  ///
  /// In es, this message translates to:
  /// **'Parada'**
  String get stop;

  /// No description provided for @route.
  ///
  /// In es, this message translates to:
  /// **'Ruta'**
  String get route;

  /// No description provided for @viewOnMap.
  ///
  /// In es, this message translates to:
  /// **'Ver en el mapa'**
  String get viewOnMap;

  /// No description provided for @share.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get share;

  /// No description provided for @addFavorite.
  ///
  /// In es, this message translates to:
  /// **'Guardar en favoritos'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favoritos'**
  String get removeFavorite;

  /// No description provided for @minutesShort.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @durationHm.
  ///
  /// In es, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHm(int hours, int minutes);

  /// No description provided for @walkSteps.
  ///
  /// In es, this message translates to:
  /// **'Indicaciones a pie'**
  String get walkSteps;

  /// No description provided for @intermediateStops.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin paradas intermedias} =1{1 parada intermedia} other{{count} paradas intermedias}}'**
  String intermediateStops(int count);

  /// No description provided for @updatedAgo.
  ///
  /// In es, this message translates to:
  /// **'Actualizado hace {seconds} s'**
  String updatedAgo(int seconds);

  /// No description provided for @vehiclesCount.
  ///
  /// In es, this message translates to:
  /// **'{count} vehículos'**
  String vehiclesCount(int count);

  /// No description provided for @swap.
  ///
  /// In es, this message translates to:
  /// **'Intercambiar origen y destino'**
  String get swap;

  /// No description provided for @places.
  ///
  /// In es, this message translates to:
  /// **'Lugares'**
  String get places;

  /// No description provided for @tapToSetPlace.
  ///
  /// In es, this message translates to:
  /// **'Toca el mapa para elegir el punto'**
  String get tapToSetPlace;

  /// No description provided for @longPressHint.
  ///
  /// In es, this message translates to:
  /// **'Mantén presionado el mapa para fijar un punto'**
  String get longPressHint;

  /// No description provided for @setAsOrigin.
  ///
  /// In es, this message translates to:
  /// **'Usar como origen'**
  String get setAsOrigin;

  /// No description provided for @setAsDestination.
  ///
  /// In es, this message translates to:
  /// **'Usar como destino'**
  String get setAsDestination;

  /// No description provided for @home.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get home;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @version.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get version;

  /// No description provided for @dataSource.
  ///
  /// In es, this message translates to:
  /// **'Fuente de datos'**
  String get dataSource;

  /// No description provided for @mockMode.
  ///
  /// In es, this message translates to:
  /// **'Modo demostración (datos de ejemplo)'**
  String get mockMode;

  /// No description provided for @direction.
  ///
  /// In es, this message translates to:
  /// **'Sentido'**
  String get direction;

  /// No description provided for @stopsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} paradas'**
  String stopsCount(int count);

  /// No description provided for @towards.
  ///
  /// In es, this message translates to:
  /// **'Hacia {headsign}'**
  String towards(String headsign);

  /// No description provided for @walkTo.
  ///
  /// In es, this message translates to:
  /// **'Camina hasta {place}'**
  String walkTo(String place);

  /// No description provided for @rideTo.
  ///
  /// In es, this message translates to:
  /// **'Bájate en {place}'**
  String rideTo(String place);

  /// No description provided for @boardAt.
  ///
  /// In es, this message translates to:
  /// **'Sube en {place}'**
  String boardAt(String place);

  /// No description provided for @arriveAt.
  ///
  /// In es, this message translates to:
  /// **'Llegas a {place}'**
  String arriveAt(String place);

  /// No description provided for @moreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get moreOptions;

  /// No description provided for @walkingDistance.
  ///
  /// In es, this message translates to:
  /// **'Distancia máxima a pie'**
  String get walkingDistance;

  /// No description provided for @changeCity.
  ///
  /// In es, this message translates to:
  /// **'Cambiar de ciudad'**
  String get changeCity;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get loading;

  /// No description provided for @inMinutes.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String inMinutes(int minutes);

  /// No description provided for @arrivingNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get arrivingNow;

  /// No description provided for @seeAlerts.
  ///
  /// In es, this message translates to:
  /// **'Ver alertas'**
  String get seeAlerts;

  /// No description provided for @affectedRoutes.
  ///
  /// In es, this message translates to:
  /// **'Rutas afectadas'**
  String get affectedRoutes;

  /// No description provided for @componentTrunk.
  ///
  /// In es, this message translates to:
  /// **'Troncal'**
  String get componentTrunk;

  /// No description provided for @componentFeeder.
  ///
  /// In es, this message translates to:
  /// **'Alimentador'**
  String get componentFeeder;

  /// No description provided for @componentDual.
  ///
  /// In es, this message translates to:
  /// **'Dual'**
  String get componentDual;

  /// No description provided for @componentZonal.
  ///
  /// In es, this message translates to:
  /// **'Zonal'**
  String get componentZonal;

  /// No description provided for @componentCable.
  ///
  /// In es, this message translates to:
  /// **'Cable'**
  String get componentCable;

  /// No description provided for @componentRail.
  ///
  /// In es, this message translates to:
  /// **'Tren'**
  String get componentRail;

  /// No description provided for @componentOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get componentOther;

  /// No description provided for @modeWalk.
  ///
  /// In es, this message translates to:
  /// **'A pie'**
  String get modeWalk;

  /// No description provided for @modeBus.
  ///
  /// In es, this message translates to:
  /// **'Bus'**
  String get modeBus;

  /// No description provided for @modeRail.
  ///
  /// In es, this message translates to:
  /// **'Tren'**
  String get modeRail;

  /// No description provided for @modeSubway.
  ///
  /// In es, this message translates to:
  /// **'Metro'**
  String get modeSubway;

  /// No description provided for @modeTram.
  ///
  /// In es, this message translates to:
  /// **'Tranvía'**
  String get modeTram;

  /// No description provided for @modeCableCar.
  ///
  /// In es, this message translates to:
  /// **'Cable'**
  String get modeCableCar;

  /// No description provided for @modeBicycle.
  ///
  /// In es, this message translates to:
  /// **'Bicicleta'**
  String get modeBicycle;

  /// No description provided for @modeCar.
  ///
  /// In es, this message translates to:
  /// **'Carro'**
  String get modeCar;

  /// No description provided for @modeFerry.
  ///
  /// In es, this message translates to:
  /// **'Ferry'**
  String get modeFerry;

  /// No description provided for @modeTransit.
  ///
  /// In es, this message translates to:
  /// **'Transporte público'**
  String get modeTransit;

  /// No description provided for @locationDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin permiso de ubicación. Actívalo en los ajustes del sistema.'**
  String get locationDenied;

  /// No description provided for @reverseTrip.
  ///
  /// In es, this message translates to:
  /// **'Invertir viaje'**
  String get reverseTrip;

  /// No description provided for @openInPlanner.
  ///
  /// In es, this message translates to:
  /// **'Abrir en el planeador'**
  String get openInPlanner;

  /// No description provided for @goHere.
  ///
  /// In es, this message translates to:
  /// **'Ir aquí'**
  String get goHere;

  /// No description provided for @leaveFrom.
  ///
  /// In es, this message translates to:
  /// **'Salir de aquí'**
  String get leaveFrom;

  /// No description provided for @fromHere.
  ///
  /// In es, this message translates to:
  /// **'Desde aquí'**
  String get fromHere;

  /// No description provided for @accessible.
  ///
  /// In es, this message translates to:
  /// **'Accesible'**
  String get accessible;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
