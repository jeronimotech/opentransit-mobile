// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'OpenTransit';

  @override
  String get chooseCity => 'Scegli la tua città';

  @override
  String get detectCity => 'Rileva la mia città';

  @override
  String get detectingCity => 'Cerco la tua città…';

  @override
  String cityDetected(String city) {
    return 'Sei a $city';
  }

  @override
  String get cityNotCovered =>
      'Non copriamo ancora la tua zona. Scegli una città dalla lista.';

  @override
  String get cityDetectFailed =>
      'Non siamo riusciti a usare la tua posizione. Scegli una città dalla lista.';

  @override
  String get chooseCitySubtitle =>
      'Pianifica viaggi con i mezzi pubblici usando dati aperti e in tempo reale.';

  @override
  String get searchPlaceholder => 'Dove vai?';

  @override
  String get planTrip => 'Pianifica viaggio';

  @override
  String get fromLabel => 'Partenza';

  @override
  String get toLabel => 'Destinazione';

  @override
  String get myLocation => 'La mia posizione';

  @override
  String get chooseOnMap => 'Scegli sulla mappa';

  @override
  String get departAt => 'Parti alle';

  @override
  String get arriveBy => 'Arriva entro le';

  @override
  String get now => 'Adesso';

  @override
  String get wheelchair => 'Accessibile in sedia a rotelle';

  @override
  String get modes => 'Mezzi';

  @override
  String get searchAction => 'Cerca';

  @override
  String get results => 'Risultati';

  @override
  String get noItineraries =>
      'Non abbiamo trovato itinerari per questo viaggio. Prova un altro orario o aumenta la distanza a piedi.';

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambi',
      one: '1 cambio',
      zero: 'Senza cambi',
    );
    return '$_temp0';
  }

  @override
  String walkDistance(int meters) {
    return '$meters m a piedi';
  }

  @override
  String get itinerary => 'Itinerario';

  @override
  String get departures => 'Prossime partenze';

  @override
  String get noDepartures => 'Nessuna partenza programmata nella prossima ora.';

  @override
  String get realtime => 'In tempo reale';

  @override
  String get scheduled => 'Da orario';

  @override
  String get canceled => 'Cancellato';

  @override
  String delayedBy(int minutes) {
    return 'Ritardo di $minutes min';
  }

  @override
  String earlyBy(int minutes) {
    return 'In anticipo di $minutes min';
  }

  @override
  String get onTime => 'In orario';

  @override
  String get alerts => 'Avvisi';

  @override
  String get noAlerts => 'Nessun avviso attivo.';

  @override
  String get favorites => 'Preferiti';

  @override
  String get noFavorites =>
      'Salva fermate, linee e luoghi per averli sempre a portata di mano.';

  @override
  String get settings => 'Impostazioni';

  @override
  String get city => 'Città';

  @override
  String get language => 'Lingua';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get accessibility => 'Accessibilità';

  @override
  String get wheelchairPref => 'Preferisci percorsi accessibili';

  @override
  String get liveVehicles => 'Veicoli in tempo reale';

  @override
  String get nearbyStops => 'Fermate vicine';

  @override
  String get retry => 'Riprova';

  @override
  String get errorGeneric =>
      'Qualcosa è andato storto. Controlla la connessione e riprova.';

  @override
  String get errorOffline => 'Nessuna connessione con il server.';

  @override
  String get routes => 'Linee';

  @override
  String get stops => 'Fermate';

  @override
  String get stop => 'Fermata';

  @override
  String get route => 'Linea';

  @override
  String get viewOnMap => 'Vedi sulla mappa';

  @override
  String get share => 'Condividi';

  @override
  String get addFavorite => 'Salva nei preferiti';

  @override
  String get removeFavorite => 'Togli dai preferiti';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHm(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get walkSteps => 'Indicazioni a piedi';

  @override
  String intermediateStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fermate intermedie',
      one: '1 fermata intermedia',
      zero: 'Nessuna fermata intermedia',
    );
    return '$_temp0';
  }

  @override
  String updatedAgo(int seconds) {
    return 'Aggiornato $seconds s fa';
  }

  @override
  String vehiclesCount(int count) {
    return '$count veicoli';
  }

  @override
  String get swap => 'Scambia partenza e destinazione';

  @override
  String get places => 'Luoghi';

  @override
  String get tapToSetPlace => 'Tocca la mappa per scegliere il punto';

  @override
  String get longPressHint => 'Tieni premuto sulla mappa per fissare un punto';

  @override
  String get setAsOrigin => 'Usa come partenza';

  @override
  String get setAsDestination => 'Usa come destinazione';

  @override
  String get home => 'Home';

  @override
  String get about => 'Info';

  @override
  String get version => 'Versione';

  @override
  String get dataSource => 'Fonte dei dati';

  @override
  String get mockMode => 'Modalità dimostrativa (dati di esempio)';

  @override
  String get direction => 'Direzione';

  @override
  String stopsCount(int count) {
    return '$count fermate';
  }

  @override
  String towards(String headsign) {
    return 'Direzione $headsign';
  }

  @override
  String walkTo(String place) {
    return 'Cammina fino a $place';
  }

  @override
  String rideTo(String place) {
    return 'Scendi a $place';
  }

  @override
  String boardAt(String place) {
    return 'Sali a $place';
  }

  @override
  String arriveAt(String place) {
    return 'Arrivi a $place';
  }

  @override
  String get moreOptions => 'Più opzioni';

  @override
  String get walkingDistance => 'Distanza massima a piedi';

  @override
  String get changeCity => 'Cambia città';

  @override
  String get loading => 'Caricamento…';

  @override
  String inMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get arrivingNow => 'Adesso';

  @override
  String get seeAlerts => 'Vedi avvisi';

  @override
  String get affectedRoutes => 'Linee interessate';

  @override
  String get componentTrunk => 'Linea principale';

  @override
  String get componentFeeder => 'Linea di adduzione';

  @override
  String get componentDual => 'Dual';

  @override
  String get componentZonal => 'Zonale';

  @override
  String get componentCable => 'Funivia';

  @override
  String get componentRail => 'Treno';

  @override
  String get componentTram => 'Tram';

  @override
  String get componentBus => 'Bus';

  @override
  String get componentOther => 'Altro';

  @override
  String get modeWalk => 'A piedi';

  @override
  String get modeBus => 'Bus';

  @override
  String get modeRail => 'Treno';

  @override
  String get modeSubway => 'Metro';

  @override
  String get modeTram => 'Tram';

  @override
  String get modeCableCar => 'Funivia';

  @override
  String get modeBicycle => 'Bicicletta';

  @override
  String get modeCar => 'Auto';

  @override
  String get modeFerry => 'Traghetto';

  @override
  String get modeTransit => 'Trasporto pubblico';

  @override
  String get locationDenied =>
      'Nessun permesso di posizione. Attivalo nelle impostazioni del sistema.';

  @override
  String get reverseTrip => 'Inverti viaggio';

  @override
  String get openInPlanner => 'Apri nel pianificatore';

  @override
  String get goHere => 'Vai qui';

  @override
  String get leaveFrom => 'Parti da qui';

  @override
  String get fromHere => 'Da qui';

  @override
  String get accessible => 'Accessibile';

  @override
  String get hubTitle => 'Cosa vuoi consultare?';

  @override
  String get tilePlan => 'Pianifica viaggio';

  @override
  String get tileLocate => 'Trova il tuo bus';

  @override
  String get tileNearby => 'Fermate vicine';

  @override
  String get tileRoutes => 'Cerca linea';

  @override
  String get tileLive => 'Bus in tempo reale';

  @override
  String get tileAlerts => 'Avvisi';

  @override
  String get tileFavorites => 'Preferiti';

  @override
  String get nearbyCardTitle => 'Stazioni e fermate vicine';

  @override
  String get services => 'Servizi';

  @override
  String get messagesOfInterest => 'Messaggi utili';

  @override
  String get dismiss => 'Nascondi';

  @override
  String get seeAll => 'Vedi tutti';

  @override
  String get locateTitle => 'Trova il tuo bus';

  @override
  String get locateStep1 => 'Scegli una stazione o una fermata';

  @override
  String get locateStep2 => 'Scegli la linea';

  @override
  String get locateNext => 'Prossimi bus';

  @override
  String get sourceLive => 'In tempo reale';

  @override
  String get sourceScheduled => 'Da orario';

  @override
  String get sourceEstimated => 'Stimato';

  @override
  String stopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fermate',
      one: '1 fermata',
    );
    return '$_temp0';
  }

  @override
  String get noBuses => 'Nessun bus in arrivo per questa linea.';

  @override
  String get searchStopHint => 'Cerca stazione o fermata';

  @override
  String get changeStop => 'Cambia fermata';

  @override
  String get board => 'Prossimi bus';

  @override
  String nextIn(int minutes) {
    return 'Prossimo tra $minutes min';
  }

  @override
  String thenAt(String list) {
    return 'poi $list';
  }

  @override
  String get noBoard => 'Nessun bus nella prossima ora.';

  @override
  String get freshLive => 'In tempo reale';

  @override
  String get freshScheduled => 'Da orario';

  @override
  String freshStale(int seconds) {
    return 'Senza dati in tempo reale da $seconds s';
  }

  @override
  String get freshNoRealtime => 'Senza dati in tempo reale';

  @override
  String get outOfHours => 'Fuori orario';

  @override
  String nextAt(String time) {
    return 'prossimo $time';
  }

  @override
  String get noServiceToday => 'Nessun servizio oggi';

  @override
  String get serviceHours => 'Orario';

  @override
  String get estimatedFare => 'Tariffa stimata';

  @override
  String get fareNotPublished => 'Tariffa non pubblicata';

  @override
  String get fareBase => 'Biglietto';

  @override
  String get fareTransfer => 'Cambio';

  @override
  String get fareEstimatedNote =>
      'Stima con la tariffa configurata per la città; può variare.';

  @override
  String get sortFastest => 'Più veloce';

  @override
  String get sortFewerTransfers => 'Meno cambi';

  @override
  String get sortLessWalking => 'Meno a piedi';

  @override
  String get sortCheapest => 'Più economico';

  @override
  String get sortEarliest => 'Partenza più vicina';

  @override
  String get sortBy => 'Ordina';

  @override
  String get favHome => 'Casa';

  @override
  String get favWork => 'Lavoro';

  @override
  String get favCustom => 'Altro';

  @override
  String get saveAs => 'Salva come';

  @override
  String get recentTrips => 'Viaggi recenti';

  @override
  String get clearRecent => 'Cancella';

  @override
  String get setHome => 'Imposta Casa';

  @override
  String get setWork => 'Imposta Lavoro';

  @override
  String get chooseIcon => 'Scegli un\'icona';

  @override
  String get saveFavorite => 'Salva preferito';

  @override
  String get favoriteName => 'Nome';

  @override
  String get updateRequired => 'Aggiorna l\'app';

  @override
  String get updateRequiredBody =>
      'Questa versione non è più supportata. Aggiorna per continuare a usare OpenTransit.';

  @override
  String get updateAction => 'Aggiorna';

  @override
  String get updateOpenFailed =>
      'Impossibile aprire lo store. Cercaci come «opentransit» per aggiornare.';

  @override
  String get maintenanceTitle => 'In manutenzione';

  @override
  String get maintenanceBody =>
      'Stiamo facendo dei miglioramenti. Riprova tra qualche minuto.';

  @override
  String get checkAgain => 'Riprova';

  @override
  String get shareCopied => 'Link copiato';

  @override
  String get shareTrip => 'Condividi viaggio';

  @override
  String get copyLink => 'Copia link';

  @override
  String get openInWeb => 'Apri sul web';

  @override
  String get startTrip => 'Avvia viaggio';

  @override
  String get stopTrip => 'Termina';

  @override
  String get currentLeg => 'Tratta attuale';

  @override
  String get nextStopIsYours => 'La prossima fermata è la tua';

  @override
  String getOffAt(String stop) {
    return 'Scendi a $stop';
  }

  @override
  String get followAlongHint =>
      'Ti avvisiamo quando ti avvicini alla tua fermata di discesa.';

  @override
  String progressLabel(int done, int total) {
    return 'Tratta $done di $total';
  }

  @override
  String get arrived => 'Sei arrivato!';

  @override
  String distanceToStop(String distance) {
    return '$distance alla tua fermata';
  }

  @override
  String get followAlongLocationNeeded =>
      'Ci serve la tua posizione per seguire il viaggio.';

  @override
  String get poiLayer => 'Servizi nelle stazioni';

  @override
  String get poiBikeParking => 'Parcheggio bici';

  @override
  String get poiToilets => 'Bagni';

  @override
  String get poiAtm => 'Bancomat';

  @override
  String get poiHealth => 'Presidio sanitario';

  @override
  String get poiLibrary => 'Biblioteca';

  @override
  String get poiOther => 'Servizio';

  @override
  String get accessibilityUnverified => 'Dato del feed non verificato';

  @override
  String get accessibilityNotAccessible => 'Non accessibile';

  @override
  String get accessibilityUnknown => 'Nessuna informazione sull\'accessibilità';

  @override
  String accessibilitySource(String source) {
    return 'Fonte: $source';
  }

  @override
  String get accessibilityVerified => 'Verificato';

  @override
  String get nearYou => 'Vicino a te';

  @override
  String get bikeToStation => 'Arriva in bici alla stazione';

  @override
  String get reportProblem => 'Segnala un problema';

  @override
  String get pqrs => 'Reclami';

  @override
  String get openExternal => 'Apri link';

  @override
  String get rechargeCard => 'Ricarica la tessera';

  @override
  String get routesSearchHint => 'Cerca linea (es. 64)';

  @override
  String get station => 'Stazione';

  @override
  String get etaLegend => '≤5 · ≤10 · ≤15 min';

  @override
  String get live => 'In tempo reale';

  @override
  String get allRoutes => 'Tutte le linee';

  @override
  String get noRoutes => 'Nessuna linea trovata.';

  @override
  String minutesOnly(int minutes) {
    return '$minutes min';
  }

  @override
  String get now2 => 'Ora';

  @override
  String vehicleAgo(int seconds) {
    return '$seconds s fa';
  }

  @override
  String get goToStop => 'Vai alla fermata';

  @override
  String get showOnMap => 'Vedi sulla mappa';

  @override
  String get selectRoute => 'Seleziona una linea';

  @override
  String get layers => 'Livelli';

  @override
  String get layerLive => 'Bus in tempo reale';

  @override
  String get layerLiveHint => 'Compaiono ingrandendo la mappa (zoom 14+)';

  @override
  String get layerPois => 'Servizi';

  @override
  String get layerNetwork => 'Rete delle linee';

  @override
  String get nearYouTitle => 'Vicino a te';

  @override
  String get zoomInForBuses => 'Ingrandisci la mappa per vedere i bus';

  @override
  String get actionPlan => 'Pianifica viaggio';

  @override
  String get actionLocate => 'Trova il tuo bus';

  @override
  String get actionRoutes => 'Cerca linea';

  @override
  String get timeNow => 'Adesso';

  @override
  String get timeSheetTitle => 'Quando viaggi?';

  @override
  String get modeBike => 'Bici';

  @override
  String get modeWalkShort => 'A piedi';

  @override
  String routesCount(int count) {
    return 'Linee · $count';
  }

  @override
  String get viewOnMapAction => 'Vedi sulla mappa';

  @override
  String get noNearbyStops => 'Nessuna fermata vicino a questo punto';

  @override
  String get done => 'Fatto';

  @override
  String get layerNetworkHint => 'Percorsi della rete principale';

  @override
  String get layerNetworkZonalHint => 'Centinaia di percorsi sovrapposti';

  @override
  String thenTimes(String times) {
    return 'poi $times min';
  }

  @override
  String get modeBikeShare => 'Bike sharing';

  @override
  String rentalPickup(String station) {
    return 'Prendi una bici a $station';
  }

  @override
  String rentalDropoff(String station) {
    return 'Lascia la bici a $station';
  }

  @override
  String rentalRide(String duration, String distance) {
    return 'Pedala $duration · $distance';
  }

  @override
  String bikesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bici disponibili',
      one: '1 bici disponibile',
      zero: 'Nessuna bici disponibile',
    );
    return '$_temp0';
  }

  @override
  String docksAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stalli liberi',
      one: '1 stallo libero',
      zero: 'Nessuno stallo libero',
    );
    return '$_temp0';
  }

  @override
  String bikesShort(int count) {
    return '$count bici';
  }

  @override
  String ebikesShort(int count) {
    return '$count elettriche';
  }

  @override
  String docksShort(int count) {
    return '$count stalli';
  }

  @override
  String openApp(String name) {
    return 'Apri $name';
  }

  @override
  String get layerBikeShare => 'Bike sharing';

  @override
  String get layerBikeShareHint => 'Stazioni e bici disponibili (zoom 14+)';

  @override
  String get rentalStation => 'Stazione di bici';

  @override
  String get howToGetThere => 'Come arrivare';

  @override
  String noRentalData(String name) {
    return 'Nessun dato di $name adesso';
  }

  @override
  String get rentalNotRenting => 'Non consegna bici in questo momento';

  @override
  String get rentalNotReturning => 'Non accetta bici in questo momento';

  @override
  String rentalPriceLine(String amount, String label) {
    return '≈ $amount · $label';
  }

  @override
  String get rentalDockHint =>
      'All\'arrivo, lascia la bici agganciata alla stazione.';

  @override
  String sharedBikeOf(String name) {
    return 'Bike sharing · $name';
  }

  @override
  String get electricBike => 'elettrica';

  @override
  String get rentalUnavailableHint => 'Nessun dato di stazioni in questa zona.';

  @override
  String get modeScooter => 'Monopattino';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'Aggiornato $minutes min fa';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'Aggiornato $hours h fa';
  }

  @override
  String get modeOnDemand => 'Taxi / app';

  @override
  String get onDemandTaxi => 'Taxi';

  @override
  String get onDemandRidehail => 'App di trasporto';

  @override
  String get priceInApp => 'Prezzo nell\'app';

  @override
  String get requestRide => 'Chiama';

  @override
  String get requestVehicle => 'Chiama il tuo veicolo';

  @override
  String requestVehicleTo(String place) {
    return 'Chiama il tuo veicolo verso $place';
  }

  @override
  String onDemandRideLine(String duration, String distance) {
    return '$duration · $distance in auto';
  }

  @override
  String get chooseProvider => 'Scegli come chiamarlo';

  @override
  String get recommended => 'Consigliato';

  @override
  String waitMinutes(int minutes) {
    return '$minutes min di attesa';
  }

  @override
  String tariffSource(String source) {
    return 'Stima secondo $source · fa fede il tassametro';
  }

  @override
  String get onDemandToHere => 'Arriva in taxi / app';

  @override
  String get onDemandNoProviders =>
      'Non ci sono taxi né app di trasporto configurati in questa città.';

  @override
  String get onDemandOpenFailed => 'Impossibile aprire l\'app del provider.';

  @override
  String get taxiToBus => 'Taxi → Bus';

  @override
  String get onDemandOffline => 'Impossibile ottenere la stima del viaggio.';

  @override
  String requestProviderPriced(String name, String price) {
    return 'Chiama $name · $price';
  }

  @override
  String requestWithProvider(String name) {
    return 'Chiama con $name';
  }

  @override
  String get orRequestWith => 'Oppure chiama con:';

  @override
  String get seePrices => 'Vedi prezzi';

  @override
  String get hidePrices => 'Nascondi prezzi';

  @override
  String onDemandDestination(String place) {
    return 'Verso $place';
  }

  @override
  String get viewFullRoute => 'Vedi la linea completa';

  @override
  String get locateNoLive => 'Nessun bus in tempo reale su questa linea adesso';

  @override
  String locateNoneComing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus in corsa',
      one: '1 bus in corsa',
    );
    return '$_temp0 · nessuno è ancora diretto a questa fermata';
  }

  @override
  String locateComing(int count, int coming) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus in corsa',
      one: '1 bus in corsa',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coming,
      locale: localeName,
      other: '$coming sono diretti',
      one: '1 è diretto',
    );
    return '$_temp0 · $_temp1 a questa fermata';
  }

  @override
  String get modeSharedShort => 'Sharing';

  @override
  String get modeOnDemandShort => 'Taxi/app';

  @override
  String get stateOn => 'attivato';

  @override
  String get stateOff => 'disattivato';

  @override
  String leaveIn(int minutes) {
    return 'Parti tra $minutes min';
  }

  @override
  String get leaveNow => 'Parti adesso';

  @override
  String get departed => 'Già partito';

  @override
  String get refreshResults => 'Aggiorna';

  @override
  String get scenarioFastest => 'Più veloce';

  @override
  String get scenarioLessWalking => 'Meno a piedi';

  @override
  String get scenarioFewerTransfers => 'Meno cambi';

  @override
  String get scenarioCheapest => 'Più economico';

  @override
  String get scenarioBike => 'In bici';

  @override
  String get scenarioOnDemand => 'Taxi / app';

  @override
  String get sortByScenario => 'Per scenario';

  @override
  String get orderMenu => 'Ordina';

  @override
  String moreOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count altre opzioni',
      one: '1 altra opzione',
    );
    return '$_temp0';
  }

  @override
  String get nextDeparturesHere => 'Prossime partenze da qui';

  @override
  String get retimed => 'Orari ricalcolati';

  @override
  String get retimedHint => 'Orari adattati alla partenza scelta';

  @override
  String andThenTimes(String times) {
    return 'e tra $times min';
  }

  @override
  String get noStopsNearbyWalk => 'Nessuna fermata entro 30 min a piedi';

  @override
  String get noBoardContext => 'Nessuna partenza a breve da questa fermata';

  @override
  String get noLiveScheduledBelow =>
      'Nessun bus in tempo reale su questa linea adesso · orario programmato qui sotto';

  @override
  String get offlineBar => 'Senza connessione · mostro i dati salvati';

  @override
  String get backOnlineBar => 'Connessione ripristinata';

  @override
  String staleBar(int seconds) {
    return 'Dati in tempo reale in ritardo · $seconds s fa';
  }

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get analyticsToggle => 'Condividi statistiche d\'uso anonime';

  @override
  String get analyticsExplain =>
      'Aiuta a migliorare il trasporto della tua città: solo dati anonimi e aggregati, mai la tua posizione esatta.';

  @override
  String get analyticsClear => 'Cancella le mie statistiche';

  @override
  String get analyticsCleared =>
      'Statistiche cancellate e identificativo rinnovato';

  @override
  String get privacyPolicy => 'Informativa sulla privacy';

  @override
  String get agencyPrivacyPolicy =>
      'Informativa sulla privacy dell\'azienda di trasporto';

  @override
  String get commuteToWork => 'Vai al lavoro';

  @override
  String get commuteToHome => 'Vai a casa';

  @override
  String get commuteInvert => 'Inverti';

  @override
  String get commuteSeeRoute => 'Vedi percorso';

  @override
  String get commuteNoPlan => 'Nessuna opzione adesso';

  @override
  String get commuteDetour => 'Percorso con deviazione · Ripianifica';

  @override
  String get commuteSetup =>
      'Salva Casa e Lavoro per vedere qui il tuo tragitto';

  @override
  String get departuresSheetTitle => 'Quando partire';

  @override
  String get departuresButton => 'Partenze';

  @override
  String get forecastRecommended => 'Opzione migliore';

  @override
  String forecastGap(String time) {
    return 'Dopo non c\'è servizio fino alle $time';
  }

  @override
  String get forecastEmpty => 'Non ci sono altre partenze in questa fascia';

  @override
  String forecastArrive(String time) {
    return 'arriva $time';
  }

  @override
  String get forecastPickThis => 'Pianifica a quest\'ora';

  @override
  String get routeAlertsTitle => 'Avvisi di questa linea';

  @override
  String get routeAlertsAlways => 'Sempre';

  @override
  String get routeAlertsWeekdays => 'Solo giorni feriali';

  @override
  String get routeAlertsWorkHours => 'Solo orario di lavoro';

  @override
  String get routeAlertsNever => 'Mai';

  @override
  String get routeAlertsOn => 'Avvisi attivati';

  @override
  String get routeAlertsOff => 'Avvisi disattivati';

  @override
  String routeAlertNotificationTitle(String route) {
    return '$route: novità sulla tua linea';
  }

  @override
  String get quickGo => 'GO rapido';

  @override
  String busesOnRoute(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus in corsa',
      one: '1 bus in corsa',
      zero: 'Nessun bus in tempo reale',
    );
    return '$_temp0';
  }

  @override
  String get goReceiptTitle => 'Viaggio terminato';

  @override
  String get goReceiptPlanned => 'Pianificato';

  @override
  String get goReceiptActual => 'Reale';

  @override
  String get goReceiptDistance => 'Distanza';

  @override
  String get goReceiptModes => 'Mezzi';

  @override
  String get goReceiptCost => 'Costo stimato';

  @override
  String get goReceiptCo2 => 'CO₂ evitata rispetto all\'auto';

  @override
  String get goReceiptClose => 'Fatto';

  @override
  String get goOffRoute => 'Sembra che tu sia uscito dal percorso';

  @override
  String get goReplan => 'Ripianifica';

  @override
  String get goRecenter => 'Torna alla mia posizione';

  @override
  String get goReplanFailed =>
      'Impossibile ricalcolare. Resti sul percorso precedente.';

  @override
  String get goDismiss => 'Continua così';

  @override
  String get goNotificationTitle => 'Viaggio in corso';

  @override
  String goNotificationBody(String stop, int minutes, String time) {
    return 'Scendi a $stop · $minutes min · arrivi $time';
  }

  @override
  String get goLocationWhy =>
      'Usiamo la tua posizione solo durante il viaggio, per avvisarti quando scendere.';

  @override
  String get shareTripCreating => 'Creo il link…';

  @override
  String get shareTripCopied => 'Link copiato';

  @override
  String get shareTripStop => 'Smetti di condividere';

  @override
  String get shareTripStopped => 'Il link non è più attivo';

  @override
  String get shareTripFailed => 'Impossibile creare il link';

  @override
  String get shareTripActive => 'Condivisione in tempo reale';

  @override
  String get ok => 'Ho capito';

  @override
  String get nearMeTitle => 'Vicino a me';

  @override
  String get nearMeEntry => 'Bus vicini';

  @override
  String get nearMeLoading => 'Cerco i bus…';

  @override
  String nearMeCount(int count, String radius) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus entro $radius',
      one: '1 bus entro $radius',
      zero: 'Nessun bus entro $radius',
    );
    return '$_temp0';
  }

  @override
  String nearMeEmpty(String radius) {
    return 'Nessun bus entro $radius';
  }

  @override
  String nearMeWiden(String radius) {
    return 'Amplia a $radius';
  }

  @override
  String nearMeAt(String distance) {
    return 'a $distance';
  }

  @override
  String get nearMeApproaching => 'Si avvicina';

  @override
  String get nearMeLeaving => 'Si allontana';

  @override
  String get nearMeNeedsLocation =>
      'Ci serve la tua posizione per mostrarti i bus intorno a te.';

  @override
  String get backToMyLocation => 'Torna alla mia posizione';

  @override
  String get assistantTitle => 'Chiedimi';

  @override
  String get assistantIntro =>
      'Rispondo con i dati della città: pianifico viaggi, guardo le prossime partenze e controllo le deviazioni. Se non ho modo di saperlo, te lo dico.';

  @override
  String get assistantPlaceholder => 'Chiedi di una linea o di un bus';

  @override
  String get assistantSend => 'Invia';

  @override
  String get assistantStop => 'Ferma';

  @override
  String get assistantClose => 'Chiudi';

  @override
  String get assistantThinking => 'Sto pensando…';

  @override
  String assistantNotice(String provider) {
    return 'Le tue domande vengono inviate a $provider per redigere la risposta. Non inviamo la tua posizione esatta né salviamo la conversazione.';
  }

  @override
  String get assistantSuggestion1 => 'Come arrivo in centro?';

  @override
  String get assistantSuggestion2 => 'A che ora passa il prossimo bus?';

  @override
  String get assistantSuggestion3 => 'Ci sono deviazioni oggi?';

  @override
  String get assistantToolPlanTrip => 'Cerco percorsi…';

  @override
  String get assistantToolFindPlace => 'Cerco il luogo…';

  @override
  String get assistantToolNextDepartures => 'Consulto le prossime partenze…';

  @override
  String get assistantToolLocateBus => 'Localizzo il bus…';

  @override
  String get assistantToolServiceAlerts => 'Controllo le deviazioni…';

  @override
  String get assistantToolFareEstimate => 'Calcolo la tariffa…';

  @override
  String get assistantToolNearbyStops => 'Cerco fermate vicine…';

  @override
  String get assistantToolBikeStations => 'Cerco bici…';

  @override
  String get assistantToolVehiclesNear => 'Cerco bus vicini…';

  @override
  String get assistantToolRouteInfo => 'Consulto la linea…';

  @override
  String get assistantErrBudget =>
      'L\'assistente ha raggiunto il suo budget di oggi. Torna domani o usa il pianificatore.';

  @override
  String get assistantErrDisabled =>
      'L\'assistente non è disponibile in questa città.';

  @override
  String get assistantErrRate =>
      'Vai troppo veloce. Aspetta un momento e riprova a chiedere.';

  @override
  String get assistantErrUpstream =>
      'Non sono riuscito a rispondere adesso. Riprova.';

  @override
  String get assistantNewConversation => 'Nuova conversazione';

  @override
  String get assistantNewConfirm =>
      'Iniziare una nuova conversazione? Quello che hai chiesto finora verrà cancellato.';

  @override
  String get assistantNewConfirmCta => 'Ricomincia';

  @override
  String get cancel => 'Annulla';

  @override
  String get pickOnMapHint => 'Sposta la mappa per scegliere il punto';

  @override
  String get pickOnMapSearching => 'Cerco l\'indirizzo…';

  @override
  String get pickOnMapConfirmOrigin => 'Conferma partenza';

  @override
  String get pickOnMapConfirmDestination => 'Conferma destinazione';

  @override
  String get dragPinsHint =>
      'Trascina i segnaposto per spostare la partenza o la destinazione';

  @override
  String get replanning => 'Ricalcolo il viaggio…';

  @override
  String get replanFailed => 'Impossibile ricalcolare il viaggio';

  @override
  String get placeTypeStation => 'Stazione';

  @override
  String get placeTypeStop => 'Fermata';

  @override
  String get placeTypeAddress => 'Indirizzo';

  @override
  String get placeTypeStreet => 'Via';

  @override
  String get placeTypePlace => 'Luogo';

  @override
  String get placeOptions => 'Opzioni del luogo';

  @override
  String get modeParkRide => 'Auto + mezzi';

  @override
  String get modeParkRideShort => 'Auto+bus';

  @override
  String get scenarioParkRide => 'Auto + mezzi';

  @override
  String get layerParking => 'Parcheggio a pagamento';

  @override
  String get layerParkingHint =>
      'Zone con posti liberi, secondo l\'ultimo conteggio (zoom 14+)';

  @override
  String get parkingZone => 'Zona di parcheggio a pagamento';

  @override
  String get parkingOwnCar => 'La tua auto';

  @override
  String parkingLeaveCarAt(String place) {
    return 'Lascia l\'auto a $place';
  }

  @override
  String parkingSpaces(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n posti',
      one: '1 posto',
    );
    return '$_temp0';
  }

  @override
  String parkingSpacesOf(int n, int total) {
    return '$n posti su $total';
  }

  @override
  String get parkingUnknownSpaces => 'Posti senza conteggio';

  @override
  String get parkingFull => 'Nessun posto';

  @override
  String get parkingAllowedNow => 'Puoi parcheggiare adesso';

  @override
  String get parkingNotNow => 'Non si può parcheggiare adesso';

  @override
  String parkingUntil(String time) {
    return 'fino alle $time';
  }

  @override
  String get parkingNoCount => 'Il gestore non pubblica il conteggio';

  @override
  String parkingFeeFor(int hours) {
    return 'Parcheggio $hours h';
  }

  @override
  String parkingThenWalk(String distance, String duration) {
    return 'Poi $distance a piedi ($duration) fino alla fermata';
  }

  @override
  String get parkingContinueByTransit => 'Prosegui con i mezzi';

  @override
  String get tripsTitle => 'Viaggi programmati';

  @override
  String get tripsSettingsHint => 'Avvisi la sera prima e all\'ora di partire';

  @override
  String get tripsEmpty =>
      'Programma un viaggio da un risultato o dal tuo tragitto Casa ⇄ Lavoro e ti avvisiamo quando partire.';

  @override
  String get tripsRefresh => 'Ricalcola';

  @override
  String get scheduleTrip => 'Programma viaggio';

  @override
  String get scheduleTripHint =>
      'Ti avvisiamo la sera prima con l\'ora di partenza, 20 minuti prima con i dati in tempo reale, e all\'ora di partire.';

  @override
  String get scheduleArriveBy => 'Arriva alle';

  @override
  String get scheduleDepartAt => 'Parti alle';

  @override
  String get scheduleRepeat => 'Ripeti';

  @override
  String get scheduleOnce => 'Una volta';

  @override
  String get scheduleSave => 'Programma';

  @override
  String get scheduleSaved =>
      'Fatto. Ti avvisiamo la sera prima e all\'ora di partire.';

  @override
  String get scheduleNotifDenied =>
      'Viaggio salvato, ma senza il permesso per le notifiche non possiamo avvisarti.';

  @override
  String get tripWeekdays => 'Lun–Ven';

  @override
  String get tripDaily => 'Tutti i giorni';

  @override
  String get tripWeekend => 'Fine settimana';

  @override
  String tripOnceOn(String date) {
    return '$date';
  }

  @override
  String tripArriveAt(String time) {
    return 'arrivare $time';
  }

  @override
  String tripDepartAt(String time) {
    return 'partire $time';
  }

  @override
  String tripLeaveAround(String time) {
    return 'Parti ~$time';
  }

  @override
  String get tripPlanning => 'Calcolo l\'ora di partenza…';

  @override
  String get tripPast => 'Già passato';

  @override
  String get tripDeleted => 'Viaggio eliminato';

  @override
  String tripEveTitle(String to) {
    return 'Domani: $to';
  }

  @override
  String tripEveBody(String leave, String arrive, String routes) {
    return 'Parti alle $leave per arrivare alle $arrive · $routes';
  }

  @override
  String tripRefineTitle(String leave) {
    return 'Parti alle $leave';
  }

  @override
  String tripRefineBody(String routes, String arrive) {
    return '$routes · arrivi alle $arrive';
  }

  @override
  String get tripLeaveTitle => 'È ora di partire';

  @override
  String tripLeaveBody(String to, String routes, String arrive) {
    return 'Verso $to · $routes · arrivi alle $arrive';
  }

  @override
  String get remindersPermissionOk => 'Avvisi consentiti';

  @override
  String get remindersPermissionUnknown =>
      'Verifico il permesso per le notifiche…';

  @override
  String get remindersPermissionDenied =>
      'Le notifiche sono disattivate per opentransit: gli avvisi vengono programmati, ma il telefono non li mostra.';

  @override
  String get remindersOpenSettings => 'Consenti notifiche';

  @override
  String get remindersTest => 'Prova avviso';

  @override
  String get remindersTestScheduled =>
      'Riceverai un avviso di prova tra 10 secondi.';

  @override
  String get remindersTestTitle => 'Avviso di prova';

  @override
  String get remindersTestBody =>
      'Così appariranno i tuoi promemoria di viaggio.';

  @override
  String remindersArmed(String kinds) {
    return 'Avvisi attivi: $kinds';
  }

  @override
  String get remindersEve => 'sera prima';

  @override
  String get remindersLeave => 'ora di partire';

  @override
  String get remindersNone =>
      'Nessun avviso attivo — controlla il permesso per le notifiche';
}
