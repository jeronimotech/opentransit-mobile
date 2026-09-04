// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenTransit';

  @override
  String get chooseCity => 'Choose your city';

  @override
  String get chooseCitySubtitle =>
      'Plan public transport trips with open, real-time data.';

  @override
  String get searchPlaceholder => 'Where to?';

  @override
  String get planTrip => 'Plan a trip';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get myLocation => 'My location';

  @override
  String get chooseOnMap => 'Choose on map';

  @override
  String get departAt => 'Depart at';

  @override
  String get arriveBy => 'Arrive by';

  @override
  String get now => 'Now';

  @override
  String get wheelchair => 'Wheelchair accessible';

  @override
  String get modes => 'Modes';

  @override
  String get searchAction => 'Search';

  @override
  String get results => 'Results';

  @override
  String get noItineraries =>
      'No itineraries found for this trip. Try another time or a longer walking distance.';

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '1 transfer',
      zero: 'No transfers',
    );
    return '$_temp0';
  }

  @override
  String walkDistance(int meters) {
    return '$meters m walk';
  }

  @override
  String get itinerary => 'Itinerary';

  @override
  String get departures => 'Next departures';

  @override
  String get noDepartures => 'No scheduled departures in the next hour.';

  @override
  String get realtime => 'Live';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get canceled => 'Canceled';

  @override
  String delayedBy(int minutes) {
    return '$minutes min late';
  }

  @override
  String earlyBy(int minutes) {
    return '$minutes min early';
  }

  @override
  String get onTime => 'On time';

  @override
  String get alerts => 'Alerts';

  @override
  String get noAlerts => 'No active alerts.';

  @override
  String get favorites => 'Favorites';

  @override
  String get noFavorites => 'Save stops, routes and places to keep them handy.';

  @override
  String get settings => 'Settings';

  @override
  String get city => 'City';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get wheelchairPref => 'Prefer accessible routes';

  @override
  String get liveVehicles => 'Live vehicles';

  @override
  String get nearbyStops => 'Nearby stops';

  @override
  String get retry => 'Retry';

  @override
  String get errorGeneric =>
      'Something went wrong. Check your connection and try again.';

  @override
  String get errorOffline => 'Cannot reach the server.';

  @override
  String get routes => 'Routes';

  @override
  String get stops => 'Stops';

  @override
  String get stop => 'Stop';

  @override
  String get route => 'Route';

  @override
  String get viewOnMap => 'View on map';

  @override
  String get share => 'Share';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHm(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get walkSteps => 'Walking directions';

  @override
  String intermediateStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count intermediate stops',
      one: '1 intermediate stop',
      zero: 'No intermediate stops',
    );
    return '$_temp0';
  }

  @override
  String updatedAgo(int seconds) {
    return 'Updated $seconds s ago';
  }

  @override
  String vehiclesCount(int count) {
    return '$count vehicles';
  }

  @override
  String get swap => 'Swap origin and destination';

  @override
  String get places => 'Places';

  @override
  String get tapToSetPlace => 'Tap the map to pick a point';

  @override
  String get longPressHint => 'Long-press the map to set a point';

  @override
  String get setAsOrigin => 'Set as origin';

  @override
  String get setAsDestination => 'Set as destination';

  @override
  String get home => 'Home';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get dataSource => 'Data source';

  @override
  String get mockMode => 'Demo mode (sample data)';

  @override
  String get direction => 'Direction';

  @override
  String stopsCount(int count) {
    return '$count stops';
  }

  @override
  String towards(String headsign) {
    return 'Towards $headsign';
  }

  @override
  String walkTo(String place) {
    return 'Walk to $place';
  }

  @override
  String rideTo(String place) {
    return 'Get off at $place';
  }

  @override
  String boardAt(String place) {
    return 'Board at $place';
  }

  @override
  String arriveAt(String place) {
    return 'Arrive at $place';
  }

  @override
  String get moreOptions => 'More options';

  @override
  String get walkingDistance => 'Maximum walking distance';

  @override
  String get changeCity => 'Change city';

  @override
  String get loading => 'Loading…';

  @override
  String inMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get arrivingNow => 'Now';

  @override
  String get seeAlerts => 'See alerts';

  @override
  String get affectedRoutes => 'Affected routes';

  @override
  String get componentTrunk => 'Trunk';

  @override
  String get componentFeeder => 'Feeder';

  @override
  String get componentDual => 'Dual';

  @override
  String get componentZonal => 'Zonal';

  @override
  String get componentCable => 'Cable';

  @override
  String get componentRail => 'Rail';

  @override
  String get componentOther => 'Other';

  @override
  String get modeWalk => 'Walk';

  @override
  String get modeBus => 'Bus';

  @override
  String get modeRail => 'Rail';

  @override
  String get modeSubway => 'Subway';

  @override
  String get modeTram => 'Tram';

  @override
  String get modeCableCar => 'Cable car';

  @override
  String get modeBicycle => 'Bicycle';

  @override
  String get modeCar => 'Car';

  @override
  String get modeFerry => 'Ferry';

  @override
  String get modeTransit => 'Public transport';

  @override
  String get locationDenied =>
      'Location permission denied. Enable it in system settings.';

  @override
  String get reverseTrip => 'Reverse trip';

  @override
  String get openInPlanner => 'Open in planner';

  @override
  String get goHere => 'Go here';

  @override
  String get leaveFrom => 'Leave from here';

  @override
  String get fromHere => 'From here';

  @override
  String get accessible => 'Accessible';
}
