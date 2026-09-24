// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'OpenTransit';

  @override
  String get chooseCity => 'Choisissez votre ville';

  @override
  String get detectCity => 'Détecter ma ville';

  @override
  String get detectingCity => 'Recherche de votre ville…';

  @override
  String cityDetected(String city) {
    return 'Vous êtes à $city';
  }

  @override
  String get cityNotCovered =>
      'Nous ne couvrons pas encore votre zone. Choisissez une ville dans la liste.';

  @override
  String get cityDetectFailed =>
      'Impossible d’utiliser votre position. Choisissez une ville dans la liste.';

  @override
  String get chooseCitySubtitle =>
      'Planifiez vos trajets en transport en commun avec des données ouvertes et en temps réel.';

  @override
  String get searchPlaceholder => 'Où allez-vous ?';

  @override
  String get planTrip => 'Planifier un trajet';

  @override
  String get fromLabel => 'Départ';

  @override
  String get toLabel => 'Arrivée';

  @override
  String get myLocation => 'Ma position';

  @override
  String get chooseOnMap => 'Choisir sur la carte';

  @override
  String get departAt => 'Partir à';

  @override
  String get arriveBy => 'Arriver avant';

  @override
  String get now => 'Maintenant';

  @override
  String get wheelchair => 'Accessible en fauteuil roulant';

  @override
  String get modes => 'Modes';

  @override
  String get searchAction => 'Rechercher';

  @override
  String get results => 'Résultats';

  @override
  String get noItineraries =>
      'Aucun itinéraire trouvé pour ce trajet. Essayez un autre horaire ou augmentez la distance à pied.';

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correspondances',
      one: '1 correspondance',
      zero: 'Sans correspondance',
    );
    return '$_temp0';
  }

  @override
  String walkDistance(int meters) {
    return '$meters m à pied';
  }

  @override
  String get itinerary => 'Itinéraire';

  @override
  String get departures => 'Prochains départs';

  @override
  String get noDepartures => 'Aucun départ prévu dans l’heure qui vient.';

  @override
  String get realtime => 'En direct';

  @override
  String get scheduled => 'Théorique';

  @override
  String get canceled => 'Annulé';

  @override
  String delayedBy(int minutes) {
    return 'Retard de $minutes min';
  }

  @override
  String earlyBy(int minutes) {
    return 'En avance de $minutes min';
  }

  @override
  String get onTime => 'À l’heure';

  @override
  String get alerts => 'Alertes';

  @override
  String get noAlerts => 'Aucune alerte en cours.';

  @override
  String get favorites => 'Favoris';

  @override
  String get noFavorites =>
      'Enregistrez des arrêts, des lignes et des lieux pour les avoir sous la main.';

  @override
  String get settings => 'Réglages';

  @override
  String get city => 'Ville';

  @override
  String get language => 'Langue';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get accessibility => 'Accessibilité';

  @override
  String get wheelchairPref => 'Préférer les itinéraires accessibles';

  @override
  String get liveVehicles => 'Véhicules en direct';

  @override
  String get nearbyStops => 'Arrêts à proximité';

  @override
  String get retry => 'Réessayer';

  @override
  String get errorGeneric =>
      'Une erreur s’est produite. Vérifiez votre connexion et réessayez.';

  @override
  String get errorOffline => 'Pas de connexion au serveur.';

  @override
  String get routes => 'Lignes';

  @override
  String get stops => 'Arrêts';

  @override
  String get stop => 'Arrêt';

  @override
  String get route => 'Ligne';

  @override
  String get viewOnMap => 'Voir sur la carte';

  @override
  String get share => 'Partager';

  @override
  String get addFavorite => 'Ajouter aux favoris';

  @override
  String get removeFavorite => 'Retirer des favoris';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHm(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get walkSteps => 'Itinéraire à pied';

  @override
  String intermediateStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arrêts intermédiaires',
      one: '1 arrêt intermédiaire',
      zero: 'Sans arrêt intermédiaire',
    );
    return '$_temp0';
  }

  @override
  String updatedAgo(int seconds) {
    return 'Mis à jour il y a $seconds s';
  }

  @override
  String vehiclesCount(int count) {
    return '$count véhicules';
  }

  @override
  String get swap => 'Inverser départ et arrivée';

  @override
  String get places => 'Lieux';

  @override
  String get tapToSetPlace => 'Touchez la carte pour choisir le point';

  @override
  String get longPressHint =>
      'Appuyez longuement sur la carte pour placer un point';

  @override
  String get setAsOrigin => 'Utiliser comme départ';

  @override
  String get setAsDestination => 'Utiliser comme arrivée';

  @override
  String get home => 'Accueil';

  @override
  String get about => 'À propos';

  @override
  String get version => 'Version';

  @override
  String get dataSource => 'Source des données';

  @override
  String get mockMode => 'Mode démonstration (données d’exemple)';

  @override
  String get direction => 'Direction';

  @override
  String stopsCount(int count) {
    return '$count arrêts';
  }

  @override
  String towards(String headsign) {
    return 'Direction $headsign';
  }

  @override
  String walkTo(String place) {
    return 'Marchez jusqu’à $place';
  }

  @override
  String rideTo(String place) {
    return 'Descendez à $place';
  }

  @override
  String boardAt(String place) {
    return 'Montez à $place';
  }

  @override
  String arriveAt(String place) {
    return 'Vous arrivez à $place';
  }

  @override
  String get moreOptions => 'Plus d’options';

  @override
  String get walkingDistance => 'Distance maximale à pied';

  @override
  String get changeCity => 'Changer de ville';

  @override
  String get loading => 'Chargement…';

  @override
  String inMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get arrivingNow => 'Maintenant';

  @override
  String get seeAlerts => 'Voir les alertes';

  @override
  String get affectedRoutes => 'Lignes concernées';

  @override
  String get componentTrunk => 'Ligne principale';

  @override
  String get componentFeeder => 'Rabattement';

  @override
  String get componentDual => 'Mixte';

  @override
  String get componentZonal => 'Zonale';

  @override
  String get componentCable => 'Téléphérique';

  @override
  String get componentRail => 'Train';

  @override
  String get componentTram => 'Tramway';

  @override
  String get componentBus => 'Bus';

  @override
  String get componentOther => 'Autre';

  @override
  String get modeWalk => 'À pied';

  @override
  String get modeBus => 'Bus';

  @override
  String get modeRail => 'Train';

  @override
  String get modeSubway => 'Métro';

  @override
  String get modeTram => 'Tramway';

  @override
  String get modeCableCar => 'Téléphérique';

  @override
  String get modeBicycle => 'Vélo';

  @override
  String get modeCar => 'Voiture';

  @override
  String get modeFerry => 'Ferry';

  @override
  String get modeTransit => 'Transport en commun';

  @override
  String get locationDenied =>
      'Pas d’autorisation de localisation. Activez-la dans les réglages du système.';

  @override
  String get reverseTrip => 'Inverser le trajet';

  @override
  String get openInPlanner => 'Ouvrir dans le planificateur';

  @override
  String get goHere => 'Y aller';

  @override
  String get leaveFrom => 'Partir d’ici';

  @override
  String get fromHere => 'Depuis ici';

  @override
  String get accessible => 'Accessible';

  @override
  String get hubTitle => 'Que souhaitez-vous consulter ?';

  @override
  String get tilePlan => 'Planifier un trajet';

  @override
  String get tileLocate => 'Localiser mon bus';

  @override
  String get tileNearby => 'Arrêts à proximité';

  @override
  String get tileRoutes => 'Chercher une ligne';

  @override
  String get tileLive => 'Bus en direct';

  @override
  String get tileAlerts => 'Alertes';

  @override
  String get tileFavorites => 'Favoris';

  @override
  String get nearbyCardTitle => 'Stations et arrêts à proximité';

  @override
  String get services => 'Services';

  @override
  String get messagesOfInterest => 'Messages utiles';

  @override
  String get dismiss => 'Masquer';

  @override
  String get seeAll => 'Tout voir';

  @override
  String get locateTitle => 'Localiser mon bus';

  @override
  String get locateStep1 => 'Choisissez une station ou un arrêt';

  @override
  String get locateStep2 => 'Choisissez la ligne';

  @override
  String get locateNext => 'Prochains bus';

  @override
  String get sourceLive => 'En direct';

  @override
  String get sourceScheduled => 'Horaire théorique';

  @override
  String get sourceEstimated => 'Estimé';

  @override
  String stopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arrêts',
      one: '1 arrêt',
    );
    return '$_temp0';
  }

  @override
  String get noBuses => 'Aucun bus prochainement sur cette ligne.';

  @override
  String get searchStopHint => 'Chercher une station ou un arrêt';

  @override
  String get changeStop => 'Changer d’arrêt';

  @override
  String get board => 'Prochains bus';

  @override
  String nextIn(int minutes) {
    return 'Prochain dans $minutes min';
  }

  @override
  String thenAt(String list) {
    return 'puis $list';
  }

  @override
  String get noBoard => 'Aucun bus dans l’heure qui vient.';

  @override
  String get freshLive => 'En direct';

  @override
  String get freshScheduled => 'Théorique';

  @override
  String freshStale(int seconds) {
    return 'Pas de données en direct depuis $seconds s';
  }

  @override
  String get freshNoRealtime => 'Pas de données en direct';

  @override
  String get outOfHours => 'Hors service';

  @override
  String nextAt(String time) {
    return 'prochain $time';
  }

  @override
  String get noServiceToday => 'Pas de service aujourd’hui';

  @override
  String get serviceHours => 'Horaires';

  @override
  String get estimatedFare => 'Tarif estimé';

  @override
  String get fareNotPublished => 'Tarif non publié';

  @override
  String get fareBase => 'Ticket';

  @override
  String get fareTransfer => 'Correspondance';

  @override
  String get fareEstimatedNote =>
      'Estimation selon le tarif configuré pour la ville ; peut varier.';

  @override
  String get sortFastest => 'Le plus rapide';

  @override
  String get sortFewerTransfers => 'Moins de correspondances';

  @override
  String get sortLessWalking => 'Moins de marche';

  @override
  String get sortCheapest => 'Le moins cher';

  @override
  String get sortEarliest => 'Départ le plus proche';

  @override
  String get sortBy => 'Trier';

  @override
  String get favHome => 'Domicile';

  @override
  String get favWork => 'Travail';

  @override
  String get favCustom => 'Autre';

  @override
  String get saveAs => 'Enregistrer sous';

  @override
  String get recentTrips => 'Trajets récents';

  @override
  String get clearRecent => 'Effacer';

  @override
  String get setHome => 'Définir le domicile';

  @override
  String get setWork => 'Définir le travail';

  @override
  String get chooseIcon => 'Choisissez une icône';

  @override
  String get saveFavorite => 'Enregistrer le favori';

  @override
  String get favoriteName => 'Nom';

  @override
  String get updateRequired => 'Mettez à jour l’appli';

  @override
  String get updateRequiredBody =>
      'Cette version n’est plus compatible. Mettez à jour pour continuer à utiliser OpenTransit.';

  @override
  String get updateAction => 'Mettre à jour';

  @override
  String get updateOpenFailed =>
      'Impossible d’ouvrir la boutique. Cherchez « opentransit » pour mettre à jour.';

  @override
  String get maintenanceTitle => 'En maintenance';

  @override
  String get maintenanceBody =>
      'Nous effectuons des améliorations. Réessayez dans quelques minutes.';

  @override
  String get checkAgain => 'Réessayer';

  @override
  String get shareCopied => 'Lien copié';

  @override
  String get shareTrip => 'Partager le trajet';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get openInWeb => 'Ouvrir sur le web';

  @override
  String get startTrip => 'Démarrer le trajet';

  @override
  String get stopTrip => 'Terminer';

  @override
  String get currentLeg => 'Étape en cours';

  @override
  String get nextStopIsYours => 'Le prochain arrêt est le vôtre';

  @override
  String getOffAt(String stop) {
    return 'Descendez à $stop';
  }

  @override
  String get followAlongHint =>
      'Nous vous prévenons à l’approche de votre arrêt de descente.';

  @override
  String progressLabel(int done, int total) {
    return 'Étape $done sur $total';
  }

  @override
  String get arrived => 'Vous êtes arrivé !';

  @override
  String distanceToStop(String distance) {
    return '$distance de votre arrêt';
  }

  @override
  String get followAlongLocationNeeded =>
      'Nous avons besoin de votre position pour suivre le trajet.';

  @override
  String get poiLayer => 'Services dans les stations';

  @override
  String get poiBikeParking => 'Parking à vélos';

  @override
  String get poiToilets => 'Toilettes';

  @override
  String get poiAtm => 'Distributeur';

  @override
  String get poiHealth => 'Point santé';

  @override
  String get poiLibrary => 'Bibliothèque';

  @override
  String get poiOther => 'Service';

  @override
  String get accessibilityUnverified => 'Donnée du flux non vérifiée';

  @override
  String get accessibilityNotAccessible => 'Non accessible';

  @override
  String get accessibilityUnknown => 'Pas d’information d’accessibilité';

  @override
  String accessibilitySource(String source) {
    return 'Source : $source';
  }

  @override
  String get accessibilityVerified => 'Vérifié';

  @override
  String get nearYou => 'Autour de vous';

  @override
  String get bikeToStation => 'Rejoindre la station à vélo';

  @override
  String get reportProblem => 'Signaler un problème';

  @override
  String get pqrs => 'Réclamations';

  @override
  String get openExternal => 'Ouvrir le lien';

  @override
  String get rechargeCard => 'Recharger ma carte';

  @override
  String get routesSearchHint => 'Chercher une ligne (p. ex. L10)';

  @override
  String get station => 'Station';

  @override
  String get etaLegend => '≤5 · ≤10 · ≤15 min';

  @override
  String get live => 'En direct';

  @override
  String get allRoutes => 'Toutes les lignes';

  @override
  String get noRoutes => 'Aucune ligne trouvée.';

  @override
  String minutesOnly(int minutes) {
    return '$minutes min';
  }

  @override
  String get now2 => 'Là';

  @override
  String vehicleAgo(int seconds) {
    return 'il y a $seconds s';
  }

  @override
  String get goToStop => 'Aller à l’arrêt';

  @override
  String get showOnMap => 'Voir sur la carte';

  @override
  String get selectRoute => 'Sélectionnez une ligne';

  @override
  String get layers => 'Couches';

  @override
  String get layerLive => 'Bus en direct';

  @override
  String get layerLiveHint => 'Affichés en zoomant sur la carte (zoom 14+)';

  @override
  String get layerPois => 'Services';

  @override
  String get layerNetwork => 'Réseau de lignes';

  @override
  String get nearYouTitle => 'Autour de vous';

  @override
  String get zoomInForBuses => 'Zoomez sur la carte pour voir les bus';

  @override
  String get actionPlan => 'Planifier un trajet';

  @override
  String get actionLocate => 'Localiser mon bus';

  @override
  String get actionRoutes => 'Chercher une ligne';

  @override
  String get timeNow => 'Maintenant';

  @override
  String get timeSheetTitle => 'Quand partez-vous ?';

  @override
  String get modeBike => 'Vélo';

  @override
  String get modeWalkShort => 'À pied';

  @override
  String routesCount(int count) {
    return 'Lignes · $count';
  }

  @override
  String get viewOnMapAction => 'Voir sur la carte';

  @override
  String get noNearbyStops => 'Aucun arrêt près de ce point';

  @override
  String get done => 'Terminé';

  @override
  String get layerNetworkHint => 'Tracés du réseau principal';

  @override
  String get layerNetworkZonalHint => 'Des centaines de tracés superposés';

  @override
  String thenTimes(String times) {
    return 'puis $times min';
  }

  @override
  String get modeBikeShare => 'Vélo en libre-service';

  @override
  String rentalPickup(String station) {
    return 'Prenez un vélo à $station';
  }

  @override
  String rentalDropoff(String station) {
    return 'Déposez le vélo à $station';
  }

  @override
  String rentalRide(String duration, String distance) {
    return 'Pédalez $duration · $distance';
  }

  @override
  String bikesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vélos disponibles',
      one: '1 vélo disponible',
      zero: 'Aucun vélo disponible',
    );
    return '$_temp0';
  }

  @override
  String docksAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bornes libres',
      one: '1 borne libre',
      zero: 'Aucune borne libre',
    );
    return '$_temp0';
  }

  @override
  String bikesShort(int count) {
    return '$count vélos';
  }

  @override
  String ebikesShort(int count) {
    return '$count électriques';
  }

  @override
  String docksShort(int count) {
    return '$count bornes';
  }

  @override
  String openApp(String name) {
    return 'Ouvrir $name';
  }

  @override
  String get layerBikeShare => 'Vélos en libre-service';

  @override
  String get layerBikeShareHint => 'Stations et vélos disponibles (zoom 14+)';

  @override
  String get rentalStation => 'Station de vélos';

  @override
  String get howToGetThere => 'Comment y aller';

  @override
  String noRentalData(String name) {
    return 'Pas de données $name pour le moment';
  }

  @override
  String get rentalNotRenting => 'Ne prête pas de vélos pour le moment';

  @override
  String get rentalNotReturning => 'N’accepte pas de vélos pour le moment';

  @override
  String rentalPriceLine(String amount, String label) {
    return '≈ $amount · $label';
  }

  @override
  String get rentalDockHint =>
      'À l’arrivée, laissez le vélo accroché à la station.';

  @override
  String sharedBikeOf(String name) {
    return 'Vélo en libre-service · $name';
  }

  @override
  String get electricBike => 'électrique';

  @override
  String get rentalUnavailableHint =>
      'Pas de données de stations dans cette zone.';

  @override
  String get modeScooter => 'Trottinette';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'Mis à jour il y a $minutes min';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'Mis à jour il y a $hours h';
  }

  @override
  String get modeOnDemand => 'Taxi / VTC';

  @override
  String get onDemandTaxi => 'Taxi';

  @override
  String get onDemandRidehail => 'Appli VTC';

  @override
  String get priceInApp => 'Prix dans l’appli';

  @override
  String get requestRide => 'Commander';

  @override
  String get requestVehicle => 'Commandez votre véhicule';

  @override
  String requestVehicleTo(String place) {
    return 'Commandez votre véhicule vers $place';
  }

  @override
  String onDemandRideLine(String duration, String distance) {
    return '$duration · $distance en voiture';
  }

  @override
  String get chooseProvider => 'Choisissez comment commander';

  @override
  String get recommended => 'Recommandé';

  @override
  String waitMinutes(int minutes) {
    return '$minutes min d’attente';
  }

  @override
  String tariffSource(String source) {
    return 'Estimation selon $source · le compteur fait foi';
  }

  @override
  String get onDemandToHere => 'Venir en taxi / VTC';

  @override
  String get onDemandNoProviders =>
      'Aucun taxi ni appli VTC configuré dans cette ville.';

  @override
  String get onDemandOpenFailed =>
      'Impossible d’ouvrir l’appli du fournisseur.';

  @override
  String get taxiToBus => 'Taxi → Bus';

  @override
  String get onDemandOffline => 'Impossible d’obtenir l’estimation du trajet.';

  @override
  String requestProviderPriced(String name, String price) {
    return 'Commander $name · $price';
  }

  @override
  String requestWithProvider(String name) {
    return 'Commander avec $name';
  }

  @override
  String get orRequestWith => 'Ou commandez avec :';

  @override
  String get seePrices => 'Voir les prix';

  @override
  String get hidePrices => 'Masquer les prix';

  @override
  String onDemandDestination(String place) {
    return 'Vers $place';
  }

  @override
  String get viewFullRoute => 'Voir toute la ligne';

  @override
  String get locateNoLive =>
      'Aucun bus en direct sur cette ligne pour le moment';

  @override
  String locateNoneComing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus en circulation',
      one: '1 bus en circulation',
    );
    return '$_temp0 · aucun ne se dirige encore vers cet arrêt';
  }

  @override
  String locateComing(int count, int coming) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus en circulation',
      one: '1 bus en circulation',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coming,
      locale: localeName,
      other: '$coming se dirigent',
      one: '1 se dirige',
    );
    return '$_temp0 · $_temp1 vers cet arrêt';
  }

  @override
  String get modeSharedShort => 'Libre-service';

  @override
  String get modeOnDemandShort => 'Taxi/VTC';

  @override
  String get stateOn => 'activé';

  @override
  String get stateOff => 'désactivé';

  @override
  String leaveIn(int minutes) {
    return 'Partez dans $minutes min';
  }

  @override
  String get leaveNow => 'Partez maintenant';

  @override
  String get departed => 'Déjà parti';

  @override
  String get refreshResults => 'Actualiser';

  @override
  String get scenarioFastest => 'Le plus rapide';

  @override
  String get scenarioLessWalking => 'Moins de marche';

  @override
  String get scenarioFewerTransfers => 'Moins de correspondances';

  @override
  String get scenarioCheapest => 'Le moins cher';

  @override
  String get scenarioBike => 'À vélo';

  @override
  String get scenarioOnDemand => 'Taxi / VTC';

  @override
  String get sortByScenario => 'Par scénario';

  @override
  String get orderMenu => 'Trier';

  @override
  String moreOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options de plus',
      one: '1 option de plus',
    );
    return '$_temp0';
  }

  @override
  String get nextDeparturesHere => 'Prochains départs ici';

  @override
  String get retimed => 'Horaires recalés';

  @override
  String get retimedHint => 'Heures ajustées au départ choisi';

  @override
  String andThenTimes(String times) {
    return 'et dans $times min';
  }

  @override
  String get noStopsNearbyWalk => 'Aucun arrêt à 30 min à pied';

  @override
  String get noBoardContext => 'Aucun départ prochainement à cet arrêt';

  @override
  String get noLiveScheduledBelow =>
      'Aucun bus en direct sur cette ligne pour le moment · horaire théorique ci-dessous';

  @override
  String get offlineBar => 'Hors connexion · données enregistrées affichées';

  @override
  String get backOnlineBar => 'Connexion rétablie';

  @override
  String staleBar(int seconds) {
    return 'Données en direct en retard · il y a $seconds s';
  }

  @override
  String get privacyTitle => 'Confidentialité';

  @override
  String get analyticsToggle => 'Partager des statistiques d’usage anonymes';

  @override
  String get analyticsExplain =>
      'Aidez à améliorer les transports de votre ville : uniquement des données anonymes et agrégées, jamais votre position exacte.';

  @override
  String get analyticsClear => 'Effacer mes statistiques';

  @override
  String get analyticsCleared =>
      'Statistiques effacées et identifiant renouvelé';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get agencyPrivacyPolicy =>
      'Politique de confidentialité de l’opérateur';

  @override
  String get commuteToWork => 'Aller au travail';

  @override
  String get commuteToHome => 'Aller au domicile';

  @override
  String get commuteInvert => 'Inverser';

  @override
  String get commuteSeeRoute => 'Voir l’itinéraire';

  @override
  String get commuteNoPlan => 'Aucune option pour le moment';

  @override
  String get commuteDetour => 'Itinéraire avec déviation · Replanifier';

  @override
  String get commuteSetup =>
      'Enregistrez Domicile et Travail pour voir votre trajet ici';

  @override
  String get departuresSheetTitle => 'Quand partir';

  @override
  String get departuresButton => 'Départs';

  @override
  String get forecastRecommended => 'Meilleure option';

  @override
  String forecastGap(String time) {
    return 'Ensuite, pas de service jusqu’à $time';
  }

  @override
  String get forecastEmpty => 'Plus de départs dans ce créneau';

  @override
  String forecastArrive(String time) {
    return 'arrivée $time';
  }

  @override
  String get forecastPickThis => 'Planifier à cette heure';

  @override
  String get routeAlertsTitle => 'Notifications de cette ligne';

  @override
  String get routeAlertsAlways => 'Toujours';

  @override
  String get routeAlertsWeekdays => 'Jours ouvrés uniquement';

  @override
  String get routeAlertsWorkHours => 'Heures de bureau uniquement';

  @override
  String get routeAlertsNever => 'Jamais';

  @override
  String get routeAlertsOn => 'Notifications activées';

  @override
  String get routeAlertsOff => 'Notifications désactivées';

  @override
  String routeAlertNotificationTitle(String route) {
    return '$route : info sur votre ligne';
  }

  @override
  String get quickGo => 'GO rapide';

  @override
  String busesOnRoute(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus en circulation',
      one: '1 bus en circulation',
      zero: 'Aucun bus en direct',
    );
    return '$_temp0';
  }

  @override
  String get goReceiptTitle => 'Trajet terminé';

  @override
  String get goReceiptPlanned => 'Prévu';

  @override
  String get goReceiptActual => 'Réel';

  @override
  String get goReceiptDistance => 'Distance';

  @override
  String get goReceiptModes => 'Modes';

  @override
  String get goReceiptCost => 'Coût estimé';

  @override
  String get goReceiptCo2 => 'CO₂ évité vs voiture';

  @override
  String get goReceiptClose => 'Terminé';

  @override
  String get goOffRoute => 'Vous semblez avoir quitté l’itinéraire';

  @override
  String get goReplan => 'Replanifier';

  @override
  String get goRecenter => 'Revenir à ma position';

  @override
  String get goReplanFailed =>
      'Impossible de recalculer. Vous restez sur l’itinéraire précédent.';

  @override
  String get goDismiss => 'Continuer ainsi';

  @override
  String get goNotificationTitle => 'Trajet en cours';

  @override
  String goNotificationBody(String stop, int minutes, String time) {
    return 'Descendez à $stop · $minutes min · arrivée $time';
  }

  @override
  String get goLocationWhy =>
      'Nous utilisons votre position uniquement pendant le trajet, pour vous prévenir quand descendre.';

  @override
  String get shareTripCreating => 'Création du lien…';

  @override
  String get shareTripCopied => 'Lien copié';

  @override
  String get shareTripStop => 'Arrêter le partage';

  @override
  String get shareTripStopped => 'Le lien n’est plus actif';

  @override
  String get shareTripFailed => 'Impossible de créer le lien';

  @override
  String get shareTripActive => 'Partage en direct';

  @override
  String get ok => 'Compris';

  @override
  String get nearMeTitle => 'Autour de moi';

  @override
  String get nearMeEntry => 'Bus à proximité';

  @override
  String get nearMeLoading => 'Recherche de bus…';

  @override
  String nearMeCount(int count, String radius) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus à moins de $radius',
      one: '1 bus à moins de $radius',
      zero: 'Aucun bus à moins de $radius',
    );
    return '$_temp0';
  }

  @override
  String nearMeEmpty(String radius) {
    return 'Aucun bus à moins de $radius';
  }

  @override
  String nearMeWiden(String radius) {
    return 'Élargir à $radius';
  }

  @override
  String nearMeAt(String distance) {
    return 'à $distance';
  }

  @override
  String get nearMeApproaching => 'Se rapproche';

  @override
  String get nearMeLeaving => 'S’éloigne';

  @override
  String get nearMeNeedsLocation =>
      'Nous avons besoin de votre position pour vous montrer les bus autour de vous.';

  @override
  String get backToMyLocation => 'Revenir à ma position';

  @override
  String get assistantTitle => 'Posez-moi une question';

  @override
  String get assistantIntro =>
      'Je réponds avec les données de la ville : je planifie des trajets, consulte les prochains départs et vérifie les déviations. Si je n’ai pas moyen de le savoir, je vous le dis.';

  @override
  String get assistantPlaceholder =>
      'Posez une question sur une ligne ou un bus';

  @override
  String get assistantSend => 'Envoyer';

  @override
  String get assistantStop => 'Arrêter';

  @override
  String get assistantClose => 'Fermer';

  @override
  String get assistantThinking => 'Réflexion…';

  @override
  String assistantNotice(String provider) {
    return 'Vos questions sont envoyées à $provider pour rédiger la réponse. Nous n’envoyons pas votre position exacte et ne conservons pas la conversation.';
  }

  @override
  String get assistantSuggestion1 => 'Comment aller au centre-ville ?';

  @override
  String get assistantSuggestion2 => 'À quelle heure passe le prochain bus ?';

  @override
  String get assistantSuggestion3 => 'Y a-t-il des déviations aujourd’hui ?';

  @override
  String get assistantToolPlanTrip => 'Recherche d’itinéraires…';

  @override
  String get assistantToolFindPlace => 'Recherche du lieu…';

  @override
  String get assistantToolNextDepartures =>
      'Consultation des prochains départs…';

  @override
  String get assistantToolLocateBus => 'Localisation du bus…';

  @override
  String get assistantToolServiceAlerts => 'Vérification des déviations…';

  @override
  String get assistantToolFareEstimate => 'Calcul du tarif…';

  @override
  String get assistantToolNearbyStops => 'Recherche d’arrêts à proximité…';

  @override
  String get assistantToolBikeStations => 'Recherche de vélos…';

  @override
  String get assistantToolVehiclesNear => 'Recherche de bus à proximité…';

  @override
  String get assistantToolRouteInfo => 'Consultation de la ligne…';

  @override
  String get assistantErrBudget =>
      'L’assistant a atteint son budget du jour. Revenez demain ou utilisez le planificateur.';

  @override
  String get assistantErrDisabled =>
      'L’assistant n’est pas disponible dans cette ville.';

  @override
  String get assistantErrRate =>
      'Vous allez trop vite. Patientez un instant et reposez votre question.';

  @override
  String get assistantErrUpstream =>
      'Je n’ai pas pu répondre pour le moment. Réessayez.';

  @override
  String get assistantNewConversation => 'Nouvelle conversation';

  @override
  String get assistantNewConfirm =>
      'Commencer une nouvelle conversation ? Ce que vous avez demandé jusqu’ici sera effacé.';

  @override
  String get assistantNewConfirmCta => 'Recommencer';

  @override
  String get cancel => 'Annuler';

  @override
  String get pickOnMapHint => 'Déplacez la carte pour choisir le point';

  @override
  String get pickOnMapSearching => 'Recherche de l’adresse…';

  @override
  String get pickOnMapConfirmOrigin => 'Confirmer le départ';

  @override
  String get pickOnMapConfirmDestination => 'Confirmer l’arrivée';

  @override
  String get dragPinsHint =>
      'Faites glisser les repères pour déplacer le départ ou l’arrivée';

  @override
  String get replanning => 'Recalcul du trajet…';

  @override
  String get replanFailed => 'Impossible de recalculer le trajet';

  @override
  String get placeTypeStation => 'Station';

  @override
  String get placeTypeStop => 'Arrêt';

  @override
  String get placeTypeAddress => 'Adresse';

  @override
  String get placeTypeStreet => 'Rue';

  @override
  String get placeTypePlace => 'Lieu';

  @override
  String get placeOptions => 'Options du lieu';

  @override
  String get modeParkRide => 'Voiture + transport';

  @override
  String get modeParkRideShort => 'Voiture+bus';

  @override
  String get scenarioParkRide => 'Voiture + transport';

  @override
  String get layerParking => 'Stationnement payant';

  @override
  String get layerParkingHint =>
      'Zones avec des places libres, selon le dernier comptage (zoom 14+)';

  @override
  String get parkingZone => 'Zone de stationnement payant';

  @override
  String get parkingOwnCar => 'Votre voiture';

  @override
  String parkingLeaveCarAt(String place) {
    return 'Laissez la voiture à $place';
  }

  @override
  String parkingSpaces(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n places',
      one: '1 place',
    );
    return '$_temp0';
  }

  @override
  String parkingSpacesOf(int n, int total) {
    return '$n places sur $total';
  }

  @override
  String get parkingUnknownSpaces => 'Places non comptées';

  @override
  String get parkingFull => 'Complet';

  @override
  String get parkingAllowedNow => 'Vous pouvez stationner maintenant';

  @override
  String get parkingNotNow => 'Stationnement impossible pour le moment';

  @override
  String parkingUntil(String time) {
    return 'jusqu’à $time';
  }

  @override
  String get parkingNoCount => 'L’opérateur ne publie pas le comptage';

  @override
  String parkingFeeFor(int hours) {
    return 'Stationnement $hours h';
  }

  @override
  String parkingThenWalk(String distance, String duration) {
    return 'Puis $distance à pied ($duration) jusqu’à l’arrêt';
  }

  @override
  String get parkingContinueByTransit => 'Continuer en transport en commun';

  @override
  String get tripsTitle => 'Trajets programmés';

  @override
  String get tripsSettingsHint =>
      'Rappels la veille au soir et à l’heure du départ';

  @override
  String get tripsEmpty =>
      'Programmez un trajet depuis un résultat ou depuis votre trajet Domicile ⇄ Travail et nous vous préviendrons quand partir.';

  @override
  String get tripsRefresh => 'Recalculer';

  @override
  String get scheduleTrip => 'Programmer le trajet';

  @override
  String get scheduleTripHint =>
      'Nous vous prévenons la veille au soir avec l’heure de départ, 20 minutes avant avec les données en direct, et à l’heure de partir.';

  @override
  String get scheduleArriveBy => 'Arriver à';

  @override
  String get scheduleDepartAt => 'Partir à';

  @override
  String get scheduleRepeat => 'Répéter';

  @override
  String get scheduleOnce => 'Une fois';

  @override
  String get scheduleSave => 'Programmer';

  @override
  String get scheduleSaved =>
      'C’est fait. Nous vous prévenons la veille au soir et à l’heure de partir.';

  @override
  String get scheduleNotifDenied =>
      'Trajet enregistré, mais sans autorisation de notifications nous ne pouvons pas vous prévenir.';

  @override
  String get tripWeekdays => 'Lun–Ven';

  @override
  String get tripDaily => 'Tous les jours';

  @override
  String get tripWeekend => 'Week-end';

  @override
  String tripOnceOn(String date) {
    return '$date';
  }

  @override
  String tripArriveAt(String time) {
    return 'arrivée $time';
  }

  @override
  String tripDepartAt(String time) {
    return 'départ $time';
  }

  @override
  String tripLeaveAround(String time) {
    return 'Partez vers $time';
  }

  @override
  String get tripPlanning => 'Calcul de l’heure de départ…';

  @override
  String get tripPast => 'Déjà passé';

  @override
  String get tripDeleted => 'Trajet supprimé';

  @override
  String tripEveTitle(String to) {
    return 'Demain : $to';
  }

  @override
  String tripEveBody(String leave, String arrive, String routes) {
    return 'Partez à $leave pour arriver à $arrive · $routes';
  }

  @override
  String tripRefineTitle(String leave) {
    return 'Partez à $leave';
  }

  @override
  String tripRefineBody(String routes, String arrive) {
    return '$routes · arrivée à $arrive';
  }

  @override
  String get tripLeaveTitle => 'C’est l’heure de partir';

  @override
  String tripLeaveBody(String to, String routes, String arrive) {
    return 'Vers $to · $routes · arrivée à $arrive';
  }

  @override
  String get remindersPermissionOk => 'Rappels autorisés';

  @override
  String get remindersPermissionUnknown =>
      'Vérification de l’autorisation de notifications…';

  @override
  String get remindersPermissionDenied =>
      'Les notifications sont désactivées pour opentransit : les rappels sont programmés, mais le téléphone ne les affiche pas.';

  @override
  String get remindersOpenSettings => 'Autoriser les notifications';

  @override
  String get remindersTest => 'Tester un rappel';

  @override
  String get remindersTestScheduled =>
      'Vous recevrez un rappel de test dans 10 secondes.';

  @override
  String get remindersTestTitle => 'Rappel de test';

  @override
  String get remindersTestBody =>
      'Voici à quoi ressembleront vos rappels de trajet.';

  @override
  String remindersArmed(String kinds) {
    return 'Rappels programmés : $kinds';
  }

  @override
  String get remindersEve => 'veille au soir';

  @override
  String get remindersLeave => 'heure de départ';

  @override
  String get remindersNone =>
      'Aucun rappel programmé — vérifiez l’autorisation de notifications';
}
