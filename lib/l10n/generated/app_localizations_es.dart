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
}
