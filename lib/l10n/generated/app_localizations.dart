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

  /// No description provided for @hubTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué quieres consultar?'**
  String get hubTitle;

  /// No description provided for @tilePlan.
  ///
  /// In es, this message translates to:
  /// **'Planear viaje'**
  String get tilePlan;

  /// No description provided for @tileLocate.
  ///
  /// In es, this message translates to:
  /// **'Ubica tu bus'**
  String get tileLocate;

  /// No description provided for @tileNearby.
  ///
  /// In es, this message translates to:
  /// **'Paradas cerca'**
  String get tileNearby;

  /// No description provided for @tileRoutes.
  ///
  /// In es, this message translates to:
  /// **'Buscar ruta'**
  String get tileRoutes;

  /// No description provided for @tileLive.
  ///
  /// In es, this message translates to:
  /// **'Buses en vivo'**
  String get tileLive;

  /// No description provided for @tileAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas'**
  String get tileAlerts;

  /// No description provided for @tileFavorites.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get tileFavorites;

  /// No description provided for @nearbyCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Estaciones y paradas cerca'**
  String get nearbyCardTitle;

  /// No description provided for @services.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get services;

  /// No description provided for @messagesOfInterest.
  ///
  /// In es, this message translates to:
  /// **'Mensajes de interés'**
  String get messagesOfInterest;

  /// No description provided for @dismiss.
  ///
  /// In es, this message translates to:
  /// **'Ocultar'**
  String get dismiss;

  /// No description provided for @seeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todas'**
  String get seeAll;

  /// No description provided for @locateTitle.
  ///
  /// In es, this message translates to:
  /// **'Ubica tu bus'**
  String get locateTitle;

  /// No description provided for @locateStep1.
  ///
  /// In es, this message translates to:
  /// **'Elige una estación o parada'**
  String get locateStep1;

  /// No description provided for @locateStep2.
  ///
  /// In es, this message translates to:
  /// **'Elige la ruta'**
  String get locateStep2;

  /// No description provided for @locateNext.
  ///
  /// In es, this message translates to:
  /// **'Próximos buses'**
  String get locateNext;

  /// No description provided for @sourceLive.
  ///
  /// In es, this message translates to:
  /// **'En vivo'**
  String get sourceLive;

  /// No description provided for @sourceScheduled.
  ///
  /// In es, this message translates to:
  /// **'Por programación'**
  String get sourceScheduled;

  /// No description provided for @sourceEstimated.
  ///
  /// In es, this message translates to:
  /// **'Estimado'**
  String get sourceEstimated;

  /// No description provided for @stopsAway.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 parada} other{{count} paradas}}'**
  String stopsAway(int count);

  /// No description provided for @noBuses.
  ///
  /// In es, this message translates to:
  /// **'Sin buses próximos para esta ruta.'**
  String get noBuses;

  /// No description provided for @searchStopHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar estación o parada'**
  String get searchStopHint;

  /// No description provided for @changeStop.
  ///
  /// In es, this message translates to:
  /// **'Cambiar parada'**
  String get changeStop;

  /// No description provided for @board.
  ///
  /// In es, this message translates to:
  /// **'Próximos buses'**
  String get board;

  /// No description provided for @nextIn.
  ///
  /// In es, this message translates to:
  /// **'Siguiente en {minutes} min'**
  String nextIn(int minutes);

  /// No description provided for @thenAt.
  ///
  /// In es, this message translates to:
  /// **'luego {list}'**
  String thenAt(String list);

  /// No description provided for @noBoard.
  ///
  /// In es, this message translates to:
  /// **'Sin buses en la próxima hora.'**
  String get noBoard;

  /// No description provided for @freshLive.
  ///
  /// In es, this message translates to:
  /// **'En vivo'**
  String get freshLive;

  /// No description provided for @freshScheduled.
  ///
  /// In es, this message translates to:
  /// **'Programado'**
  String get freshScheduled;

  /// No description provided for @freshStale.
  ///
  /// In es, this message translates to:
  /// **'Sin datos en vivo hace {seconds} s'**
  String freshStale(int seconds);

  /// No description provided for @freshNoRealtime.
  ///
  /// In es, this message translates to:
  /// **'Sin datos en vivo'**
  String get freshNoRealtime;

  /// No description provided for @outOfHours.
  ///
  /// In es, this message translates to:
  /// **'Fuera de horario'**
  String get outOfHours;

  /// No description provided for @nextAt.
  ///
  /// In es, this message translates to:
  /// **'próximo {time}'**
  String nextAt(String time);

  /// No description provided for @noServiceToday.
  ///
  /// In es, this message translates to:
  /// **'Sin servicio hoy'**
  String get noServiceToday;

  /// No description provided for @serviceHours.
  ///
  /// In es, this message translates to:
  /// **'Horario'**
  String get serviceHours;

  /// No description provided for @estimatedFare.
  ///
  /// In es, this message translates to:
  /// **'Tarifa estimada'**
  String get estimatedFare;

  /// No description provided for @fareNotPublished.
  ///
  /// In es, this message translates to:
  /// **'Tarifa no publicada'**
  String get fareNotPublished;

  /// No description provided for @fareBase.
  ///
  /// In es, this message translates to:
  /// **'Pasaje'**
  String get fareBase;

  /// No description provided for @fareTransfer.
  ///
  /// In es, this message translates to:
  /// **'Transbordo'**
  String get fareTransfer;

  /// No description provided for @fareEstimatedNote.
  ///
  /// In es, this message translates to:
  /// **'Estimación con la tarifa configurada para la ciudad; puede variar.'**
  String get fareEstimatedNote;

  /// No description provided for @sortFastest.
  ///
  /// In es, this message translates to:
  /// **'Más rápido'**
  String get sortFastest;

  /// No description provided for @sortFewerTransfers.
  ///
  /// In es, this message translates to:
  /// **'Menos transbordos'**
  String get sortFewerTransfers;

  /// No description provided for @sortLessWalking.
  ///
  /// In es, this message translates to:
  /// **'Menos caminata'**
  String get sortLessWalking;

  /// No description provided for @sortCheapest.
  ///
  /// In es, this message translates to:
  /// **'Más económico'**
  String get sortCheapest;

  /// No description provided for @sortEarliest.
  ///
  /// In es, this message translates to:
  /// **'Salida más próxima'**
  String get sortEarliest;

  /// No description provided for @sortBy.
  ///
  /// In es, this message translates to:
  /// **'Ordenar'**
  String get sortBy;

  /// No description provided for @favHome.
  ///
  /// In es, this message translates to:
  /// **'Casa'**
  String get favHome;

  /// No description provided for @favWork.
  ///
  /// In es, this message translates to:
  /// **'Trabajo'**
  String get favWork;

  /// No description provided for @favCustom.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get favCustom;

  /// No description provided for @saveAs.
  ///
  /// In es, this message translates to:
  /// **'Guardar como'**
  String get saveAs;

  /// No description provided for @recentTrips.
  ///
  /// In es, this message translates to:
  /// **'Viajes recientes'**
  String get recentTrips;

  /// No description provided for @clearRecent.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get clearRecent;

  /// No description provided for @setHome.
  ///
  /// In es, this message translates to:
  /// **'Fijar Casa'**
  String get setHome;

  /// No description provided for @setWork.
  ///
  /// In es, this message translates to:
  /// **'Fijar Trabajo'**
  String get setWork;

  /// No description provided for @chooseIcon.
  ///
  /// In es, this message translates to:
  /// **'Elige un ícono'**
  String get chooseIcon;

  /// No description provided for @saveFavorite.
  ///
  /// In es, this message translates to:
  /// **'Guardar favorito'**
  String get saveFavorite;

  /// No description provided for @favoriteName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get favoriteName;

  /// No description provided for @updateRequired.
  ///
  /// In es, this message translates to:
  /// **'Actualiza la app'**
  String get updateRequired;

  /// No description provided for @updateRequiredBody.
  ///
  /// In es, this message translates to:
  /// **'Esta versión ya no es compatible. Actualiza para seguir usando OpenTransit.'**
  String get updateRequiredBody;

  /// No description provided for @updateAction.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get updateAction;

  /// No description provided for @maintenanceTitle.
  ///
  /// In es, this message translates to:
  /// **'En mantenimiento'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In es, this message translates to:
  /// **'Estamos haciendo mejoras. Vuelve a intentarlo en unos minutos.'**
  String get maintenanceBody;

  /// No description provided for @checkAgain.
  ///
  /// In es, this message translates to:
  /// **'Volver a intentar'**
  String get checkAgain;

  /// No description provided for @shareCopied.
  ///
  /// In es, this message translates to:
  /// **'Enlace copiado'**
  String get shareCopied;

  /// No description provided for @shareTrip.
  ///
  /// In es, this message translates to:
  /// **'Compartir viaje'**
  String get shareTrip;

  /// No description provided for @copyLink.
  ///
  /// In es, this message translates to:
  /// **'Copiar enlace'**
  String get copyLink;

  /// No description provided for @openInWeb.
  ///
  /// In es, this message translates to:
  /// **'Abrir en la web'**
  String get openInWeb;

  /// No description provided for @startTrip.
  ///
  /// In es, this message translates to:
  /// **'Iniciar viaje'**
  String get startTrip;

  /// No description provided for @stopTrip.
  ///
  /// In es, this message translates to:
  /// **'Terminar'**
  String get stopTrip;

  /// No description provided for @currentLeg.
  ///
  /// In es, this message translates to:
  /// **'Tramo actual'**
  String get currentLeg;

  /// No description provided for @nextStopIsYours.
  ///
  /// In es, this message translates to:
  /// **'Próxima parada es la tuya'**
  String get nextStopIsYours;

  /// No description provided for @getOffAt.
  ///
  /// In es, this message translates to:
  /// **'Bájate en {stop}'**
  String getOffAt(String stop);

  /// No description provided for @followAlongHint.
  ///
  /// In es, this message translates to:
  /// **'Te avisamos cuando te acerques a tu parada de bajada.'**
  String get followAlongHint;

  /// No description provided for @progressLabel.
  ///
  /// In es, this message translates to:
  /// **'Tramo {done} de {total}'**
  String progressLabel(int done, int total);

  /// No description provided for @arrived.
  ///
  /// In es, this message translates to:
  /// **'¡Llegaste!'**
  String get arrived;

  /// No description provided for @distanceToStop.
  ///
  /// In es, this message translates to:
  /// **'{distance} a tu parada'**
  String distanceToStop(String distance);

  /// No description provided for @followAlongLocationNeeded.
  ///
  /// In es, this message translates to:
  /// **'Necesitamos tu ubicación para seguir el viaje.'**
  String get followAlongLocationNeeded;

  /// No description provided for @poiLayer.
  ///
  /// In es, this message translates to:
  /// **'Servicios en estaciones'**
  String get poiLayer;

  /// No description provided for @poiBikeParking.
  ///
  /// In es, this message translates to:
  /// **'Cicloparqueadero'**
  String get poiBikeParking;

  /// No description provided for @poiToilets.
  ///
  /// In es, this message translates to:
  /// **'Baños'**
  String get poiToilets;

  /// No description provided for @poiAtm.
  ///
  /// In es, this message translates to:
  /// **'Cajero'**
  String get poiAtm;

  /// No description provided for @poiHealth.
  ///
  /// In es, this message translates to:
  /// **'Punto de salud'**
  String get poiHealth;

  /// No description provided for @poiLibrary.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca'**
  String get poiLibrary;

  /// No description provided for @poiOther.
  ///
  /// In es, this message translates to:
  /// **'Servicio'**
  String get poiOther;

  /// No description provided for @accessibilityUnverified.
  ///
  /// In es, this message translates to:
  /// **'Dato del feed no verificado'**
  String get accessibilityUnverified;

  /// No description provided for @accessibilityNotAccessible.
  ///
  /// In es, this message translates to:
  /// **'No accesible'**
  String get accessibilityNotAccessible;

  /// No description provided for @accessibilityUnknown.
  ///
  /// In es, this message translates to:
  /// **'Sin información de accesibilidad'**
  String get accessibilityUnknown;

  /// No description provided for @accessibilitySource.
  ///
  /// In es, this message translates to:
  /// **'Fuente: {source}'**
  String accessibilitySource(String source);

  /// No description provided for @accessibilityVerified.
  ///
  /// In es, this message translates to:
  /// **'Verificado'**
  String get accessibilityVerified;

  /// No description provided for @nearYou.
  ///
  /// In es, this message translates to:
  /// **'Cerca de ti'**
  String get nearYou;

  /// No description provided for @bikeToStation.
  ///
  /// In es, this message translates to:
  /// **'Llegar en bici a la estación'**
  String get bikeToStation;

  /// No description provided for @reportProblem.
  ///
  /// In es, this message translates to:
  /// **'Reportar un problema'**
  String get reportProblem;

  /// No description provided for @pqrs.
  ///
  /// In es, this message translates to:
  /// **'PQRS'**
  String get pqrs;

  /// No description provided for @openExternal.
  ///
  /// In es, this message translates to:
  /// **'Abrir enlace'**
  String get openExternal;

  /// No description provided for @rechargeCard.
  ///
  /// In es, this message translates to:
  /// **'Recargar tarjeta'**
  String get rechargeCard;

  /// No description provided for @routesSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar ruta (p. ej. B10)'**
  String get routesSearchHint;

  /// No description provided for @station.
  ///
  /// In es, this message translates to:
  /// **'Estación'**
  String get station;

  /// No description provided for @etaLegend.
  ///
  /// In es, this message translates to:
  /// **'≤5 · ≤10 · ≤15 min'**
  String get etaLegend;

  /// No description provided for @live.
  ///
  /// In es, this message translates to:
  /// **'En vivo'**
  String get live;

  /// No description provided for @allRoutes.
  ///
  /// In es, this message translates to:
  /// **'Todas las rutas'**
  String get allRoutes;

  /// No description provided for @noRoutes.
  ///
  /// In es, this message translates to:
  /// **'No encontramos rutas.'**
  String get noRoutes;

  /// No description provided for @minutesOnly.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String minutesOnly(int minutes);

  /// No description provided for @now2.
  ///
  /// In es, this message translates to:
  /// **'Ya'**
  String get now2;

  /// No description provided for @vehicleAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {seconds} s'**
  String vehicleAgo(int seconds);

  /// No description provided for @goToStop.
  ///
  /// In es, this message translates to:
  /// **'Ir a la parada'**
  String get goToStop;

  /// No description provided for @showOnMap.
  ///
  /// In es, this message translates to:
  /// **'Ver en el mapa'**
  String get showOnMap;

  /// No description provided for @selectRoute.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una ruta'**
  String get selectRoute;

  /// No description provided for @layers.
  ///
  /// In es, this message translates to:
  /// **'Capas'**
  String get layers;

  /// No description provided for @layerLive.
  ///
  /// In es, this message translates to:
  /// **'Buses en vivo'**
  String get layerLive;

  /// No description provided for @layerLiveHint.
  ///
  /// In es, this message translates to:
  /// **'Se muestran al acercar el mapa (zoom 14+)'**
  String get layerLiveHint;

  /// No description provided for @layerPois.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get layerPois;

  /// No description provided for @layerNetwork.
  ///
  /// In es, this message translates to:
  /// **'Red de rutas'**
  String get layerNetwork;

  /// No description provided for @nearYouTitle.
  ///
  /// In es, this message translates to:
  /// **'Cerca de ti'**
  String get nearYouTitle;

  /// No description provided for @zoomInForBuses.
  ///
  /// In es, this message translates to:
  /// **'Acerca el mapa para ver los buses'**
  String get zoomInForBuses;

  /// No description provided for @actionPlan.
  ///
  /// In es, this message translates to:
  /// **'Planear viaje'**
  String get actionPlan;

  /// No description provided for @actionLocate.
  ///
  /// In es, this message translates to:
  /// **'Ubica tu bus'**
  String get actionLocate;

  /// No description provided for @actionRoutes.
  ///
  /// In es, this message translates to:
  /// **'Buscar ruta'**
  String get actionRoutes;

  /// No description provided for @timeNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get timeNow;

  /// No description provided for @timeSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cuándo viajas?'**
  String get timeSheetTitle;

  /// No description provided for @modeBike.
  ///
  /// In es, this message translates to:
  /// **'Bici'**
  String get modeBike;

  /// No description provided for @modeWalkShort.
  ///
  /// In es, this message translates to:
  /// **'A pie'**
  String get modeWalkShort;

  /// No description provided for @routesCount.
  ///
  /// In es, this message translates to:
  /// **'Rutas · {count}'**
  String routesCount(int count);

  /// No description provided for @viewOnMapAction.
  ///
  /// In es, this message translates to:
  /// **'Ver en mapa'**
  String get viewOnMapAction;

  /// No description provided for @noNearbyStops.
  ///
  /// In es, this message translates to:
  /// **'No hay paradas cerca de este punto'**
  String get noNearbyStops;

  /// No description provided for @done.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get done;

  /// No description provided for @layerNetworkZonal.
  ///
  /// In es, this message translates to:
  /// **'Rutas zonales'**
  String get layerNetworkZonal;

  /// No description provided for @layerNetworkHint.
  ///
  /// In es, this message translates to:
  /// **'Troncales y cable; las zonales se superponen mucho'**
  String get layerNetworkHint;

  /// No description provided for @thenTimes.
  ///
  /// In es, this message translates to:
  /// **'luego {times} min'**
  String thenTimes(String times);

  /// No description provided for @modeBikeShare.
  ///
  /// In es, this message translates to:
  /// **'Bici pública'**
  String get modeBikeShare;

  /// No description provided for @rentalPickup.
  ///
  /// In es, this message translates to:
  /// **'Toma una bici en {station}'**
  String rentalPickup(String station);

  /// No description provided for @rentalDropoff.
  ///
  /// In es, this message translates to:
  /// **'Deja la bici en {station}'**
  String rentalDropoff(String station);

  /// No description provided for @rentalRide.
  ///
  /// In es, this message translates to:
  /// **'Pedalea {duration} · {distance}'**
  String rentalRide(String duration, String distance);

  /// No description provided for @bikesAvailable.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin bicis disponibles} =1{1 bici disponible} other{{count} bicis disponibles}}'**
  String bikesAvailable(int count);

  /// No description provided for @docksAvailable.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin puestos libres} =1{1 puesto libre} other{{count} puestos libres}}'**
  String docksAvailable(int count);

  /// No description provided for @bikesShort.
  ///
  /// In es, this message translates to:
  /// **'{count} bicis'**
  String bikesShort(int count);

  /// No description provided for @ebikesShort.
  ///
  /// In es, this message translates to:
  /// **'{count} eléctricas'**
  String ebikesShort(int count);

  /// No description provided for @docksShort.
  ///
  /// In es, this message translates to:
  /// **'{count} puestos'**
  String docksShort(int count);

  /// No description provided for @openApp.
  ///
  /// In es, this message translates to:
  /// **'Abrir {name}'**
  String openApp(String name);

  /// No description provided for @layerBikeShare.
  ///
  /// In es, this message translates to:
  /// **'Bicis públicas'**
  String get layerBikeShare;

  /// No description provided for @layerBikeShareHint.
  ///
  /// In es, this message translates to:
  /// **'Estaciones y bicis disponibles (zoom 14+)'**
  String get layerBikeShareHint;

  /// No description provided for @rentalStation.
  ///
  /// In es, this message translates to:
  /// **'Estación de bicis'**
  String get rentalStation;

  /// No description provided for @howToGetThere.
  ///
  /// In es, this message translates to:
  /// **'Cómo llegar'**
  String get howToGetThere;

  /// No description provided for @noRentalData.
  ///
  /// In es, this message translates to:
  /// **'Sin datos de {name} ahora'**
  String noRentalData(String name);

  /// No description provided for @rentalNotRenting.
  ///
  /// In es, this message translates to:
  /// **'No presta bicis en este momento'**
  String get rentalNotRenting;

  /// No description provided for @rentalNotReturning.
  ///
  /// In es, this message translates to:
  /// **'No recibe bicis en este momento'**
  String get rentalNotReturning;

  /// No description provided for @rentalPriceLine.
  ///
  /// In es, this message translates to:
  /// **'≈ {amount} · {label}'**
  String rentalPriceLine(String amount, String label);

  /// No description provided for @rentalDockHint.
  ///
  /// In es, this message translates to:
  /// **'Al llegar, deja la bici anclada en la estación.'**
  String get rentalDockHint;

  /// No description provided for @sharedBikeOf.
  ///
  /// In es, this message translates to:
  /// **'Bici pública · {name}'**
  String sharedBikeOf(String name);

  /// No description provided for @electricBike.
  ///
  /// In es, this message translates to:
  /// **'eléctrica'**
  String get electricBike;

  /// No description provided for @rentalUnavailableHint.
  ///
  /// In es, this message translates to:
  /// **'Sin datos de estaciones en esta zona.'**
  String get rentalUnavailableHint;

  /// No description provided for @modeScooter.
  ///
  /// In es, this message translates to:
  /// **'Patineta'**
  String get modeScooter;

  /// No description provided for @updatedMinutesAgo.
  ///
  /// In es, this message translates to:
  /// **'Actualizado hace {minutes} min'**
  String updatedMinutesAgo(int minutes);

  /// No description provided for @updatedHoursAgo.
  ///
  /// In es, this message translates to:
  /// **'Actualizado hace {hours} h'**
  String updatedHoursAgo(int hours);

  /// No description provided for @modeOnDemand.
  ///
  /// In es, this message translates to:
  /// **'Taxi / app'**
  String get modeOnDemand;

  /// No description provided for @onDemandTaxi.
  ///
  /// In es, this message translates to:
  /// **'Taxi'**
  String get onDemandTaxi;

  /// No description provided for @onDemandRidehail.
  ///
  /// In es, this message translates to:
  /// **'App de transporte'**
  String get onDemandRidehail;

  /// No description provided for @priceInApp.
  ///
  /// In es, this message translates to:
  /// **'Precio en la app'**
  String get priceInApp;

  /// No description provided for @requestRide.
  ///
  /// In es, this message translates to:
  /// **'Pedir'**
  String get requestRide;

  /// No description provided for @requestVehicle.
  ///
  /// In es, this message translates to:
  /// **'Pide tu vehículo'**
  String get requestVehicle;

  /// No description provided for @requestVehicleTo.
  ///
  /// In es, this message translates to:
  /// **'Pide tu vehículo hacia {place}'**
  String requestVehicleTo(String place);

  /// No description provided for @onDemandRideLine.
  ///
  /// In es, this message translates to:
  /// **'{duration} · {distance} en carro'**
  String onDemandRideLine(String duration, String distance);

  /// No description provided for @chooseProvider.
  ///
  /// In es, this message translates to:
  /// **'Elige cómo pedirlo'**
  String get chooseProvider;

  /// No description provided for @recommended.
  ///
  /// In es, this message translates to:
  /// **'Recomendado'**
  String get recommended;

  /// No description provided for @waitMinutes.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min de espera'**
  String waitMinutes(int minutes);

  /// No description provided for @tariffSource.
  ///
  /// In es, this message translates to:
  /// **'Estimación según {source} · el taxímetro manda'**
  String tariffSource(String source);

  /// No description provided for @onDemandToHere.
  ///
  /// In es, this message translates to:
  /// **'Llegar en taxi / app'**
  String get onDemandToHere;

  /// No description provided for @onDemandNoProviders.
  ///
  /// In es, this message translates to:
  /// **'No hay taxis ni apps de transporte configurados en esta ciudad.'**
  String get onDemandNoProviders;

  /// No description provided for @onDemandOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la app del proveedor.'**
  String get onDemandOpenFailed;

  /// No description provided for @taxiToBus.
  ///
  /// In es, this message translates to:
  /// **'Taxi → Bus'**
  String get taxiToBus;

  /// No description provided for @onDemandOffline.
  ///
  /// In es, this message translates to:
  /// **'No se pudo obtener la estimación del viaje.'**
  String get onDemandOffline;
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
