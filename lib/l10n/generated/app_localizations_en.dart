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

  @override
  String get hubTitle => 'What do you want to check?';

  @override
  String get tilePlan => 'Plan a trip';

  @override
  String get tileLocate => 'Find my bus';

  @override
  String get tileNearby => 'Stops nearby';

  @override
  String get tileRoutes => 'Find a route';

  @override
  String get tileLive => 'Live buses';

  @override
  String get tileAlerts => 'Alerts';

  @override
  String get tileFavorites => 'Favorites';

  @override
  String get nearbyCardTitle => 'Stations and stops nearby';

  @override
  String get services => 'Services';

  @override
  String get messagesOfInterest => 'Service messages';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get seeAll => 'See all';

  @override
  String get locateTitle => 'Find my bus';

  @override
  String get locateStep1 => 'Pick a station or stop';

  @override
  String get locateStep2 => 'Pick the route';

  @override
  String get locateNext => 'Next buses';

  @override
  String get sourceLive => 'Live';

  @override
  String get sourceScheduled => 'Scheduled';

  @override
  String get sourceEstimated => 'Estimated';

  @override
  String stopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String get noBuses => 'No upcoming buses for this route.';

  @override
  String get searchStopHint => 'Search station or stop';

  @override
  String get changeStop => 'Change stop';

  @override
  String get board => 'Next buses';

  @override
  String nextIn(int minutes) {
    return 'Next in $minutes min';
  }

  @override
  String thenAt(String list) {
    return 'then $list';
  }

  @override
  String get noBoard => 'No buses in the next hour.';

  @override
  String get freshLive => 'Live';

  @override
  String get freshScheduled => 'Scheduled';

  @override
  String freshStale(int seconds) {
    return 'No live data for $seconds s';
  }

  @override
  String get freshNoRealtime => 'No live data';

  @override
  String get outOfHours => 'Out of service hours';

  @override
  String nextAt(String time) {
    return 'next $time';
  }

  @override
  String get noServiceToday => 'No more service today';

  @override
  String get serviceHours => 'Service hours';

  @override
  String get estimatedFare => 'Estimated fare';

  @override
  String get fareNotPublished => 'Fare not published';

  @override
  String get fareBase => 'Fare';

  @override
  String get fareTransfer => 'Transfer';

  @override
  String get fareEstimatedNote =>
      'Estimate based on the city\'s configured fare; it may vary.';

  @override
  String get sortFastest => 'Fastest';

  @override
  String get sortFewerTransfers => 'Fewer transfers';

  @override
  String get sortLessWalking => 'Less walking';

  @override
  String get sortCheapest => 'Cheapest';

  @override
  String get sortEarliest => 'Earliest departure';

  @override
  String get sortBy => 'Sort';

  @override
  String get favHome => 'Home';

  @override
  String get favWork => 'Work';

  @override
  String get favCustom => 'Other';

  @override
  String get saveAs => 'Save as';

  @override
  String get recentTrips => 'Recent trips';

  @override
  String get clearRecent => 'Clear';

  @override
  String get setHome => 'Set Home';

  @override
  String get setWork => 'Set Work';

  @override
  String get chooseIcon => 'Choose an icon';

  @override
  String get saveFavorite => 'Save favorite';

  @override
  String get favoriteName => 'Name';

  @override
  String get updateRequired => 'Update the app';

  @override
  String get updateRequiredBody =>
      'This version is no longer supported. Update to keep using OpenTransit.';

  @override
  String get updateAction => 'Update';

  @override
  String get maintenanceTitle => 'Under maintenance';

  @override
  String get maintenanceBody =>
      'We\'re making improvements. Please try again in a few minutes.';

  @override
  String get checkAgain => 'Try again';

  @override
  String get shareCopied => 'Link copied';

  @override
  String get shareTrip => 'Share trip';

  @override
  String get copyLink => 'Copy link';

  @override
  String get openInWeb => 'Open on the web';

  @override
  String get startTrip => 'Start trip';

  @override
  String get stopTrip => 'End';

  @override
  String get currentLeg => 'Current leg';

  @override
  String get nextStopIsYours => 'Next stop is yours';

  @override
  String getOffAt(String stop) {
    return 'Get off at $stop';
  }

  @override
  String get followAlongHint =>
      'We\'ll notify you when you approach your alighting stop.';

  @override
  String progressLabel(int done, int total) {
    return 'Leg $done of $total';
  }

  @override
  String get arrived => 'You\'ve arrived!';

  @override
  String distanceToStop(String distance) {
    return '$distance to your stop';
  }

  @override
  String get followAlongLocationNeeded =>
      'We need your location to follow the trip.';

  @override
  String get poiLayer => 'Station services';

  @override
  String get poiBikeParking => 'Bike parking';

  @override
  String get poiToilets => 'Toilets';

  @override
  String get poiAtm => 'ATM';

  @override
  String get poiHealth => 'Health point';

  @override
  String get poiLibrary => 'Library';

  @override
  String get poiOther => 'Service';

  @override
  String get accessibilityUnverified => 'Feed data not verified';

  @override
  String get accessibilityNotAccessible => 'Not accessible';

  @override
  String get accessibilityUnknown => 'No accessibility information';

  @override
  String accessibilitySource(String source) {
    return 'Source: $source';
  }

  @override
  String get accessibilityVerified => 'Verified';

  @override
  String get nearYou => 'Near you';

  @override
  String get bikeToStation => 'Bike to the station';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get pqrs => 'Complaints (PQRS)';

  @override
  String get openExternal => 'Open link';

  @override
  String get rechargeCard => 'Top up card';

  @override
  String get routesSearchHint => 'Search route (e.g. B10)';

  @override
  String get station => 'Station';

  @override
  String get etaLegend => '≤5 · ≤10 · ≤15 min';

  @override
  String get live => 'Live';

  @override
  String get allRoutes => 'All routes';

  @override
  String get noRoutes => 'No routes found.';

  @override
  String minutesOnly(int minutes) {
    return '$minutes min';
  }

  @override
  String get now2 => 'Now';

  @override
  String vehicleAgo(int seconds) {
    return '$seconds s ago';
  }

  @override
  String get goToStop => 'Go to stop';

  @override
  String get showOnMap => 'Show on map';

  @override
  String get selectRoute => 'Select a route';

  @override
  String get layers => 'Layers';

  @override
  String get layerLive => 'Live buses';

  @override
  String get layerLiveHint => 'Shown when you zoom in (zoom 14+)';

  @override
  String get layerPois => 'Services';

  @override
  String get layerNetwork => 'Route network';

  @override
  String get nearYouTitle => 'Near you';

  @override
  String get zoomInForBuses => 'Zoom in to see buses';

  @override
  String get actionPlan => 'Plan a trip';

  @override
  String get actionLocate => 'Find my bus';

  @override
  String get actionRoutes => 'Find a route';

  @override
  String get timeNow => 'Now';

  @override
  String get timeSheetTitle => 'When are you travelling?';

  @override
  String get modeBike => 'Bike';

  @override
  String get modeWalkShort => 'Walk';

  @override
  String routesCount(int count) {
    return 'Routes · $count';
  }

  @override
  String get viewOnMapAction => 'View on map';

  @override
  String get noNearbyStops => 'No stops near this point';

  @override
  String get done => 'Done';

  @override
  String get layerNetworkZonal => 'Zonal routes';

  @override
  String get layerNetworkHint =>
      'Trunk and cable; zonal routes overlap heavily';

  @override
  String thenTimes(String times) {
    return 'then $times min';
  }

  @override
  String get modeBikeShare => 'Shared bike';

  @override
  String rentalPickup(String station) {
    return 'Pick up a bike at $station';
  }

  @override
  String rentalDropoff(String station) {
    return 'Dock the bike at $station';
  }

  @override
  String rentalRide(String duration, String distance) {
    return 'Ride $duration · $distance';
  }

  @override
  String bikesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bikes available',
      one: '1 bike available',
      zero: 'No bikes available',
    );
    return '$_temp0';
  }

  @override
  String docksAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free docks',
      one: '1 free dock',
      zero: 'No free docks',
    );
    return '$_temp0';
  }

  @override
  String bikesShort(int count) {
    return '$count bikes';
  }

  @override
  String ebikesShort(int count) {
    return '$count electric';
  }

  @override
  String docksShort(int count) {
    return '$count docks';
  }

  @override
  String openApp(String name) {
    return 'Open $name';
  }

  @override
  String get layerBikeShare => 'Shared bikes';

  @override
  String get layerBikeShareHint => 'Stations and available bikes (zoom 14+)';

  @override
  String get rentalStation => 'Bike station';

  @override
  String get howToGetThere => 'Directions';

  @override
  String noRentalData(String name) {
    return 'No $name data right now';
  }

  @override
  String get rentalNotRenting => 'Not renting right now';

  @override
  String get rentalNotReturning => 'Not accepting returns right now';

  @override
  String rentalPriceLine(String amount, String label) {
    return '≈ $amount · $label';
  }

  @override
  String get rentalDockHint => 'Dock the bike at the station when you arrive.';

  @override
  String sharedBikeOf(String name) {
    return 'Shared bike · $name';
  }

  @override
  String get electricBike => 'electric';

  @override
  String get rentalUnavailableHint => 'No station data in this area.';

  @override
  String get modeScooter => 'Scooter';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'Updated $minutes min ago';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'Updated $hours h ago';
  }

  @override
  String get modeOnDemand => 'Taxi / app';

  @override
  String get onDemandTaxi => 'Taxi';

  @override
  String get onDemandRidehail => 'Ride app';

  @override
  String get priceInApp => 'Price in the app';

  @override
  String get requestRide => 'Request';

  @override
  String get requestVehicle => 'Request your ride';

  @override
  String requestVehicleTo(String place) {
    return 'Request a ride to $place';
  }

  @override
  String onDemandRideLine(String duration, String distance) {
    return '$duration · $distance by car';
  }

  @override
  String get chooseProvider => 'Choose how to request it';

  @override
  String get recommended => 'Recommended';

  @override
  String waitMinutes(int minutes) {
    return '$minutes min wait';
  }

  @override
  String tariffSource(String source) {
    return 'Estimate based on $source · the meter rules';
  }

  @override
  String get onDemandToHere => 'Get here by taxi / app';

  @override
  String get onDemandNoProviders =>
      'No taxis or ride apps are configured for this city.';

  @override
  String get onDemandOpenFailed => 'Could not open the provider\'s app.';

  @override
  String get taxiToBus => 'Taxi → Bus';

  @override
  String get onDemandOffline => 'Could not fetch the ride estimate.';

  @override
  String requestProviderPriced(String name, String price) {
    return 'Request $name · $price';
  }

  @override
  String requestWithProvider(String name) {
    return 'Request with $name';
  }

  @override
  String get orRequestWith => 'Or request with:';

  @override
  String get seePrices => 'See prices';

  @override
  String get hidePrices => 'Hide prices';

  @override
  String onDemandDestination(String place) {
    return 'To $place';
  }

  @override
  String get viewFullRoute => 'See full route';

  @override
  String get locateNoLive => 'No live buses on this route right now';

  @override
  String locateNoneComing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses on the route',
      one: '1 bus on the route',
    );
    return '$_temp0 · none heading to this stop yet';
  }

  @override
  String locateComing(int count, int coming) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count buses on the route',
      one: '1 bus on the route',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coming,
      locale: localeName,
      other: '$coming heading',
      one: '1 heading',
    );
    return '$_temp0 · $_temp1 to this stop';
  }
}
