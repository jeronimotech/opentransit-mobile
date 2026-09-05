// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'OpenTransit';

  @override
  String get chooseCity => 'Elige tu ciudad';

  @override
  String get chooseCitySubtitle =>
      'Planea viajes en transporte público con datos abiertos y en tiempo real.';

  @override
  String get searchPlaceholder => '¿A dónde vas?';

  @override
  String get planTrip => 'Planear viaje';

  @override
  String get fromLabel => 'Origen';

  @override
  String get toLabel => 'Destino';

  @override
  String get myLocation => 'Mi ubicación';

  @override
  String get chooseOnMap => 'Elegir en el mapa';

  @override
  String get departAt => 'Salir a las';

  @override
  String get arriveBy => 'Llegar antes de';

  @override
  String get now => 'Ahora';

  @override
  String get wheelchair => 'Accesible en silla de ruedas';

  @override
  String get modes => 'Modos';

  @override
  String get searchAction => 'Buscar';

  @override
  String get results => 'Resultados';

  @override
  String get noItineraries =>
      'No encontramos itinerarios para este viaje. Prueba otro horario o amplía la distancia a pie.';

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transbordos',
      one: '1 transbordo',
      zero: 'Sin transbordos',
    );
    return '$_temp0';
  }

  @override
  String walkDistance(int meters) {
    return '$meters m a pie';
  }

  @override
  String get itinerary => 'Itinerario';

  @override
  String get departures => 'Próximas salidas';

  @override
  String get noDepartures => 'Sin salidas programadas en la próxima hora.';

  @override
  String get realtime => 'En vivo';

  @override
  String get scheduled => 'Programado';

  @override
  String get canceled => 'Cancelado';

  @override
  String delayedBy(int minutes) {
    return 'Retraso de $minutes min';
  }

  @override
  String earlyBy(int minutes) {
    return 'Adelantado $minutes min';
  }

  @override
  String get onTime => 'A tiempo';

  @override
  String get alerts => 'Alertas';

  @override
  String get noAlerts => 'No hay alertas activas.';

  @override
  String get favorites => 'Favoritos';

  @override
  String get noFavorites =>
      'Guarda paradas, rutas y lugares para tenerlos a la mano.';

  @override
  String get settings => 'Ajustes';

  @override
  String get city => 'Ciudad';

  @override
  String get language => 'Idioma';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get accessibility => 'Accesibilidad';

  @override
  String get wheelchairPref => 'Preferir rutas accesibles';

  @override
  String get liveVehicles => 'Vehículos en vivo';

  @override
  String get nearbyStops => 'Paradas cercanas';

  @override
  String get retry => 'Reintentar';

  @override
  String get errorGeneric =>
      'Algo salió mal. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get errorOffline => 'Sin conexión con el servidor.';

  @override
  String get routes => 'Rutas';

  @override
  String get stops => 'Paradas';

  @override
  String get stop => 'Parada';

  @override
  String get route => 'Ruta';

  @override
  String get viewOnMap => 'Ver en el mapa';

  @override
  String get share => 'Compartir';

  @override
  String get addFavorite => 'Guardar en favoritos';

  @override
  String get removeFavorite => 'Quitar de favoritos';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHm(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get walkSteps => 'Indicaciones a pie';

  @override
  String intermediateStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas intermedias',
      one: '1 parada intermedia',
      zero: 'Sin paradas intermedias',
    );
    return '$_temp0';
  }

  @override
  String updatedAgo(int seconds) {
    return 'Actualizado hace $seconds s';
  }

  @override
  String vehiclesCount(int count) {
    return '$count vehículos';
  }

  @override
  String get swap => 'Intercambiar origen y destino';

  @override
  String get places => 'Lugares';

  @override
  String get tapToSetPlace => 'Toca el mapa para elegir el punto';

  @override
  String get longPressHint => 'Mantén presionado el mapa para fijar un punto';

  @override
  String get setAsOrigin => 'Usar como origen';

  @override
  String get setAsDestination => 'Usar como destino';

  @override
  String get home => 'Inicio';

  @override
  String get about => 'Acerca de';

  @override
  String get version => 'Versión';

  @override
  String get dataSource => 'Fuente de datos';

  @override
  String get mockMode => 'Modo demostración (datos de ejemplo)';

  @override
  String get direction => 'Sentido';

  @override
  String stopsCount(int count) {
    return '$count paradas';
  }

  @override
  String towards(String headsign) {
    return 'Hacia $headsign';
  }

  @override
  String walkTo(String place) {
    return 'Camina hasta $place';
  }

  @override
  String rideTo(String place) {
    return 'Bájate en $place';
  }

  @override
  String boardAt(String place) {
    return 'Sube en $place';
  }

  @override
  String arriveAt(String place) {
    return 'Llegas a $place';
  }

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get walkingDistance => 'Distancia máxima a pie';

  @override
  String get changeCity => 'Cambiar de ciudad';

  @override
  String get loading => 'Cargando…';

  @override
  String inMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get arrivingNow => 'Ahora';

  @override
  String get seeAlerts => 'Ver alertas';

  @override
  String get affectedRoutes => 'Rutas afectadas';

  @override
  String get componentTrunk => 'Troncal';

  @override
  String get componentFeeder => 'Alimentador';

  @override
  String get componentDual => 'Dual';

  @override
  String get componentZonal => 'Zonal';

  @override
  String get componentCable => 'Cable';

  @override
  String get componentRail => 'Tren';

  @override
  String get componentOther => 'Otro';

  @override
  String get modeWalk => 'A pie';

  @override
  String get modeBus => 'Bus';

  @override
  String get modeRail => 'Tren';

  @override
  String get modeSubway => 'Metro';

  @override
  String get modeTram => 'Tranvía';

  @override
  String get modeCableCar => 'Cable';

  @override
  String get modeBicycle => 'Bicicleta';

  @override
  String get modeCar => 'Carro';

  @override
  String get modeFerry => 'Ferry';

  @override
  String get modeTransit => 'Transporte público';

  @override
  String get locationDenied =>
      'Sin permiso de ubicación. Actívalo en los ajustes del sistema.';

  @override
  String get reverseTrip => 'Invertir viaje';

  @override
  String get openInPlanner => 'Abrir en el planeador';

  @override
  String get goHere => 'Ir aquí';

  @override
  String get leaveFrom => 'Salir de aquí';

  @override
  String get fromHere => 'Desde aquí';

  @override
  String get accessible => 'Accesible';

  @override
  String get hubTitle => '¿Qué quieres consultar?';

  @override
  String get tilePlan => 'Planear viaje';

  @override
  String get tileLocate => 'Ubica tu bus';

  @override
  String get tileNearby => 'Paradas cerca';

  @override
  String get tileRoutes => 'Buscar ruta';

  @override
  String get tileLive => 'Buses en vivo';

  @override
  String get tileAlerts => 'Alertas';

  @override
  String get tileFavorites => 'Favoritos';

  @override
  String get nearbyCardTitle => 'Estaciones y paradas cerca';

  @override
  String get services => 'Servicios';

  @override
  String get messagesOfInterest => 'Mensajes de interés';

  @override
  String get dismiss => 'Ocultar';

  @override
  String get seeAll => 'Ver todas';

  @override
  String get locateTitle => 'Ubica tu bus';

  @override
  String get locateStep1 => 'Elige una estación o parada';

  @override
  String get locateStep2 => 'Elige la ruta';

  @override
  String get locateNext => 'Próximos buses';

  @override
  String get sourceLive => 'En vivo';

  @override
  String get sourceScheduled => 'Por programación';

  @override
  String get sourceEstimated => 'Estimado';

  @override
  String stopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas',
      one: '1 parada',
    );
    return '$_temp0';
  }

  @override
  String get noBuses => 'Sin buses próximos para esta ruta.';

  @override
  String get searchStopHint => 'Buscar estación o parada';

  @override
  String get changeStop => 'Cambiar parada';

  @override
  String get board => 'Próximos buses';

  @override
  String nextIn(int minutes) {
    return 'Siguiente en $minutes min';
  }

  @override
  String thenAt(String list) {
    return 'luego $list';
  }

  @override
  String get noBoard => 'Sin buses en la próxima hora.';

  @override
  String get freshLive => 'En vivo';

  @override
  String get freshScheduled => 'Programado';

  @override
  String freshStale(int seconds) {
    return 'Sin datos en vivo hace $seconds s';
  }

  @override
  String get freshNoRealtime => 'Sin datos en vivo';

  @override
  String get outOfHours => 'Fuera de horario';

  @override
  String nextAt(String time) {
    return 'próximo $time';
  }

  @override
  String get noServiceToday => 'Sin servicio hoy';

  @override
  String get serviceHours => 'Horario';

  @override
  String get estimatedFare => 'Tarifa estimada';

  @override
  String get fareNotPublished => 'Tarifa no publicada';

  @override
  String get fareBase => 'Pasaje';

  @override
  String get fareTransfer => 'Transbordo';

  @override
  String get fareEstimatedNote =>
      'Estimación con la tarifa configurada para la ciudad; puede variar.';

  @override
  String get sortFastest => 'Más rápido';

  @override
  String get sortFewerTransfers => 'Menos transbordos';

  @override
  String get sortLessWalking => 'Menos caminata';

  @override
  String get sortCheapest => 'Más económico';

  @override
  String get sortEarliest => 'Salida más próxima';

  @override
  String get sortBy => 'Ordenar';

  @override
  String get favHome => 'Casa';

  @override
  String get favWork => 'Trabajo';

  @override
  String get favCustom => 'Otro';

  @override
  String get saveAs => 'Guardar como';

  @override
  String get recentTrips => 'Viajes recientes';

  @override
  String get clearRecent => 'Borrar';

  @override
  String get setHome => 'Fijar Casa';

  @override
  String get setWork => 'Fijar Trabajo';

  @override
  String get chooseIcon => 'Elige un ícono';

  @override
  String get saveFavorite => 'Guardar favorito';

  @override
  String get favoriteName => 'Nombre';

  @override
  String get updateRequired => 'Actualiza la app';

  @override
  String get updateRequiredBody =>
      'Esta versión ya no es compatible. Actualiza para seguir usando OpenTransit.';

  @override
  String get updateAction => 'Actualizar';

  @override
  String get maintenanceTitle => 'En mantenimiento';

  @override
  String get maintenanceBody =>
      'Estamos haciendo mejoras. Vuelve a intentarlo en unos minutos.';

  @override
  String get checkAgain => 'Volver a intentar';

  @override
  String get shareCopied => 'Enlace copiado';

  @override
  String get shareTrip => 'Compartir viaje';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get openInWeb => 'Abrir en la web';

  @override
  String get startTrip => 'Iniciar viaje';

  @override
  String get stopTrip => 'Terminar';

  @override
  String get currentLeg => 'Tramo actual';

  @override
  String get nextStopIsYours => 'Próxima parada es la tuya';

  @override
  String getOffAt(String stop) {
    return 'Bájate en $stop';
  }

  @override
  String get followAlongHint =>
      'Te avisamos cuando te acerques a tu parada de bajada.';

  @override
  String progressLabel(int done, int total) {
    return 'Tramo $done de $total';
  }

  @override
  String get arrived => '¡Llegaste!';

  @override
  String distanceToStop(String distance) {
    return '$distance a tu parada';
  }

  @override
  String get followAlongLocationNeeded =>
      'Necesitamos tu ubicación para seguir el viaje.';

  @override
  String get poiLayer => 'Servicios en estaciones';

  @override
  String get poiBikeParking => 'Cicloparqueadero';

  @override
  String get poiToilets => 'Baños';

  @override
  String get poiAtm => 'Cajero';

  @override
  String get poiHealth => 'Punto de salud';

  @override
  String get poiLibrary => 'Biblioteca';

  @override
  String get poiOther => 'Servicio';

  @override
  String get accessibilityUnverified => 'Dato del feed no verificado';

  @override
  String get accessibilityNotAccessible => 'No accesible';

  @override
  String get accessibilityUnknown => 'Sin información de accesibilidad';

  @override
  String accessibilitySource(String source) {
    return 'Fuente: $source';
  }

  @override
  String get accessibilityVerified => 'Verificado';

  @override
  String get nearYou => 'Cerca de ti';

  @override
  String get bikeToStation => 'Llegar en bici a la estación';

  @override
  String get reportProblem => 'Reportar un problema';

  @override
  String get pqrs => 'PQRS';

  @override
  String get openExternal => 'Abrir enlace';

  @override
  String get rechargeCard => 'Recargar tarjeta';

  @override
  String get routesSearchHint => 'Buscar ruta (p. ej. B10)';

  @override
  String get station => 'Estación';

  @override
  String get etaLegend => '≤5 · ≤10 · ≤15 min';

  @override
  String get live => 'En vivo';

  @override
  String get allRoutes => 'Todas las rutas';

  @override
  String get noRoutes => 'No encontramos rutas.';

  @override
  String minutesOnly(int minutes) {
    return '$minutes min';
  }

  @override
  String get now2 => 'Ya';

  @override
  String vehicleAgo(int seconds) {
    return 'hace $seconds s';
  }

  @override
  String get goToStop => 'Ir a la parada';

  @override
  String get showOnMap => 'Ver en el mapa';

  @override
  String get selectRoute => 'Selecciona una ruta';

  @override
  String get layers => 'Capas';

  @override
  String get layerLive => 'Buses en vivo';

  @override
  String get layerLiveHint => 'Se muestran al acercar el mapa (zoom 14+)';

  @override
  String get layerPois => 'Servicios';

  @override
  String get layerNetwork => 'Red de rutas';

  @override
  String get nearYouTitle => 'Cerca de ti';

  @override
  String get zoomInForBuses => 'Acerca el mapa para ver los buses';

  @override
  String get actionPlan => 'Planear viaje';

  @override
  String get actionLocate => 'Ubica tu bus';

  @override
  String get actionRoutes => 'Buscar ruta';

  @override
  String get timeNow => 'Ahora';

  @override
  String get timeSheetTitle => '¿Cuándo viajas?';

  @override
  String get modeBike => 'Bici';

  @override
  String get modeWalkShort => 'A pie';

  @override
  String routesCount(int count) {
    return 'Rutas · $count';
  }

  @override
  String get viewOnMapAction => 'Ver en mapa';

  @override
  String get noNearbyStops => 'No hay paradas cerca de este punto';

  @override
  String get done => 'Listo';

  @override
  String get layerNetworkZonal => 'Rutas zonales';

  @override
  String get layerNetworkHint =>
      'Troncales y cable; las zonales se superponen mucho';

  @override
  String thenTimes(String times) {
    return 'luego $times min';
  }

  @override
  String get modeBikeShare => 'Bici pública';

  @override
  String rentalPickup(String station) {
    return 'Toma una bici en $station';
  }

  @override
  String rentalDropoff(String station) {
    return 'Deja la bici en $station';
  }

  @override
  String rentalRide(String duration, String distance) {
    return 'Pedalea $duration · $distance';
  }

  @override
  String bikesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bicis disponibles',
      one: '1 bici disponible',
      zero: 'Sin bicis disponibles',
    );
    return '$_temp0';
  }

  @override
  String docksAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puestos libres',
      one: '1 puesto libre',
      zero: 'Sin puestos libres',
    );
    return '$_temp0';
  }

  @override
  String bikesShort(int count) {
    return '$count bicis';
  }

  @override
  String ebikesShort(int count) {
    return '$count eléctricas';
  }

  @override
  String docksShort(int count) {
    return '$count puestos';
  }

  @override
  String openApp(String name) {
    return 'Abrir $name';
  }

  @override
  String get layerBikeShare => 'Bicis públicas';

  @override
  String get layerBikeShareHint => 'Estaciones y bicis disponibles (zoom 14+)';

  @override
  String get rentalStation => 'Estación de bicis';

  @override
  String get howToGetThere => 'Cómo llegar';

  @override
  String noRentalData(String name) {
    return 'Sin datos de $name ahora';
  }

  @override
  String get rentalNotRenting => 'No presta bicis en este momento';

  @override
  String get rentalNotReturning => 'No recibe bicis en este momento';

  @override
  String rentalPriceLine(String amount, String label) {
    return '≈ $amount · $label';
  }

  @override
  String get rentalDockHint =>
      'Al llegar, deja la bici anclada en la estación.';

  @override
  String sharedBikeOf(String name) {
    return 'Bici pública · $name';
  }

  @override
  String get electricBike => 'eléctrica';

  @override
  String get rentalUnavailableHint => 'Sin datos de estaciones en esta zona.';

  @override
  String get modeScooter => 'Patineta';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'Actualizado hace $minutes min';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'Actualizado hace $hours h';
  }

  @override
  String get modeOnDemand => 'Taxi / app';

  @override
  String get onDemandTaxi => 'Taxi';

  @override
  String get onDemandRidehail => 'App de transporte';

  @override
  String get priceInApp => 'Precio en la app';

  @override
  String get requestRide => 'Pedir';

  @override
  String get requestVehicle => 'Pide tu vehículo';

  @override
  String requestVehicleTo(String place) {
    return 'Pide tu vehículo hacia $place';
  }

  @override
  String onDemandRideLine(String duration, String distance) {
    return '$duration · $distance en carro';
  }

  @override
  String get chooseProvider => 'Elige cómo pedirlo';

  @override
  String get recommended => 'Recomendado';

  @override
  String waitMinutes(int minutes) {
    return '$minutes min de espera';
  }

  @override
  String tariffSource(String source) {
    return 'Estimación según $source · el taxímetro manda';
  }

  @override
  String get onDemandToHere => 'Llegar en taxi / app';

  @override
  String get onDemandNoProviders =>
      'No hay taxis ni apps de transporte configurados en esta ciudad.';

  @override
  String get onDemandOpenFailed => 'No se pudo abrir la app del proveedor.';

  @override
  String get taxiToBus => 'Taxi → Bus';

  @override
  String get onDemandOffline => 'No se pudo obtener la estimación del viaje.';
}
