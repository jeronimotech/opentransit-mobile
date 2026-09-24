// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'OpenTransit';

  @override
  String get chooseCity => 'Escolhe a tua cidade';

  @override
  String get detectCity => 'Detetar a minha cidade';

  @override
  String get detectingCity => 'A procurar a tua cidade…';

  @override
  String cityDetected(String city) {
    return 'Estás em $city';
  }

  @override
  String get cityNotCovered =>
      'Ainda não cobrimos a tua zona. Escolhe uma cidade da lista.';

  @override
  String get cityDetectFailed =>
      'Não conseguimos usar a tua localização. Escolhe uma cidade da lista.';

  @override
  String get chooseCitySubtitle =>
      'Planeia viagens em transportes públicos com dados abertos e em tempo real.';

  @override
  String get searchPlaceholder => 'Para onde vais?';

  @override
  String get planTrip => 'Planear viagem';

  @override
  String get fromLabel => 'Origem';

  @override
  String get toLabel => 'Destino';

  @override
  String get myLocation => 'A minha localização';

  @override
  String get chooseOnMap => 'Escolher no mapa';

  @override
  String get departAt => 'Partir às';

  @override
  String get arriveBy => 'Chegar antes das';

  @override
  String get now => 'Agora';

  @override
  String get wheelchair => 'Acessível em cadeira de rodas';

  @override
  String get modes => 'Modos';

  @override
  String get searchAction => 'Procurar';

  @override
  String get results => 'Resultados';

  @override
  String get noItineraries =>
      'Não encontrámos itinerários para esta viagem. Tenta outro horário ou alarga a distância a pé.';

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transbordos',
      one: '1 transbordo',
      zero: 'Sem transbordos',
    );
    return '$_temp0';
  }

  @override
  String walkDistance(int meters) {
    return '$meters m a pé';
  }

  @override
  String get itinerary => 'Itinerário';

  @override
  String get departures => 'Próximas partidas';

  @override
  String get noDepartures => 'Sem partidas programadas na próxima hora.';

  @override
  String get realtime => 'Em tempo real';

  @override
  String get scheduled => 'Horário';

  @override
  String get canceled => 'Cancelado';

  @override
  String delayedBy(int minutes) {
    return 'Atraso de $minutes min';
  }

  @override
  String earlyBy(int minutes) {
    return 'Adiantado $minutes min';
  }

  @override
  String get onTime => 'A horas';

  @override
  String get alerts => 'Alertas';

  @override
  String get noAlerts => 'Não há alertas ativos.';

  @override
  String get favorites => 'Favoritos';

  @override
  String get noFavorites =>
      'Guarda paragens, carreiras e lugares para os teres à mão.';

  @override
  String get settings => 'Definições';

  @override
  String get city => 'Cidade';

  @override
  String get language => 'Idioma';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get accessibility => 'Acessibilidade';

  @override
  String get wheelchairPref => 'Preferir percursos acessíveis';

  @override
  String get liveVehicles => 'Veículos em tempo real';

  @override
  String get nearbyStops => 'Paragens próximas';

  @override
  String get retry => 'Tentar de novo';

  @override
  String get errorGeneric =>
      'Algo correu mal. Verifica a tua ligação e tenta de novo.';

  @override
  String get errorOffline => 'Sem ligação ao servidor.';

  @override
  String get routes => 'Carreiras';

  @override
  String get stops => 'Paragens';

  @override
  String get stop => 'Paragem';

  @override
  String get route => 'Carreira';

  @override
  String get viewOnMap => 'Ver no mapa';

  @override
  String get share => 'Partilhar';

  @override
  String get addFavorite => 'Guardar nos favoritos';

  @override
  String get removeFavorite => 'Remover dos favoritos';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHm(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get walkSteps => 'Indicações a pé';

  @override
  String intermediateStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paragens intermédias',
      one: '1 paragem intermédia',
      zero: 'Sem paragens intermédias',
    );
    return '$_temp0';
  }

  @override
  String updatedAgo(int seconds) {
    return 'Atualizado há $seconds s';
  }

  @override
  String vehiclesCount(int count) {
    return '$count veículos';
  }

  @override
  String get swap => 'Trocar origem e destino';

  @override
  String get places => 'Lugares';

  @override
  String get tapToSetPlace => 'Toca no mapa para escolher o ponto';

  @override
  String get longPressHint => 'Mantém o mapa premido para fixar um ponto';

  @override
  String get setAsOrigin => 'Usar como origem';

  @override
  String get setAsDestination => 'Usar como destino';

  @override
  String get home => 'Início';

  @override
  String get about => 'Sobre';

  @override
  String get version => 'Versão';

  @override
  String get dataSource => 'Fonte de dados';

  @override
  String get mockMode => 'Modo de demonstração (dados de exemplo)';

  @override
  String get direction => 'Sentido';

  @override
  String stopsCount(int count) {
    return '$count paragens';
  }

  @override
  String towards(String headsign) {
    return 'Sentido $headsign';
  }

  @override
  String walkTo(String place) {
    return 'Caminha até $place';
  }

  @override
  String rideTo(String place) {
    return 'Sai em $place';
  }

  @override
  String boardAt(String place) {
    return 'Entra em $place';
  }

  @override
  String arriveAt(String place) {
    return 'Chegas a $place';
  }

  @override
  String get moreOptions => 'Mais opções';

  @override
  String get walkingDistance => 'Distância máxima a pé';

  @override
  String get changeCity => 'Mudar de cidade';

  @override
  String get loading => 'A carregar…';

  @override
  String inMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get arrivingNow => 'Agora';

  @override
  String get seeAlerts => 'Ver alertas';

  @override
  String get affectedRoutes => 'Carreiras afetadas';

  @override
  String get componentTrunk => 'Troncal';

  @override
  String get componentFeeder => 'Alimentadora';

  @override
  String get componentDual => 'Dual';

  @override
  String get componentZonal => 'Zonal';

  @override
  String get componentCable => 'Teleférico';

  @override
  String get componentRail => 'Comboio';

  @override
  String get componentTram => 'Elétrico';

  @override
  String get componentBus => 'Autocarro';

  @override
  String get componentOther => 'Outro';

  @override
  String get modeWalk => 'A pé';

  @override
  String get modeBus => 'Autocarro';

  @override
  String get modeRail => 'Comboio';

  @override
  String get modeSubway => 'Metro';

  @override
  String get modeTram => 'Elétrico';

  @override
  String get modeCableCar => 'Teleférico';

  @override
  String get modeBicycle => 'Bicicleta';

  @override
  String get modeCar => 'Carro';

  @override
  String get modeFerry => 'Barco';

  @override
  String get modeTransit => 'Transportes públicos';

  @override
  String get locationDenied =>
      'Sem permissão de localização. Ativa-a nas definições do sistema.';

  @override
  String get reverseTrip => 'Inverter viagem';

  @override
  String get openInPlanner => 'Abrir no planeador';

  @override
  String get goHere => 'Ir para aqui';

  @override
  String get leaveFrom => 'Partir daqui';

  @override
  String get fromHere => 'A partir daqui';

  @override
  String get accessible => 'Acessível';

  @override
  String get hubTitle => 'O que queres consultar?';

  @override
  String get tilePlan => 'Planear viagem';

  @override
  String get tileLocate => 'Localiza o autocarro';

  @override
  String get tileNearby => 'Paragens perto';

  @override
  String get tileRoutes => 'Procurar carreira';

  @override
  String get tileLive => 'Autocarros em tempo real';

  @override
  String get tileAlerts => 'Alertas';

  @override
  String get tileFavorites => 'Favoritos';

  @override
  String get nearbyCardTitle => 'Estações e paragens perto';

  @override
  String get services => 'Serviços';

  @override
  String get messagesOfInterest => 'Mensagens de interesse';

  @override
  String get dismiss => 'Ocultar';

  @override
  String get seeAll => 'Ver todas';

  @override
  String get locateTitle => 'Localiza o autocarro';

  @override
  String get locateStep1 => 'Escolhe uma estação ou paragem';

  @override
  String get locateStep2 => 'Escolhe a carreira';

  @override
  String get locateNext => 'Próximos autocarros';

  @override
  String get sourceLive => 'Em tempo real';

  @override
  String get sourceScheduled => 'Segundo o horário';

  @override
  String get sourceEstimated => 'Estimado';

  @override
  String stopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paragens',
      one: '1 paragem',
    );
    return '$_temp0';
  }

  @override
  String get noBuses => 'Sem autocarros próximos para esta carreira.';

  @override
  String get searchStopHint => 'Procurar estação ou paragem';

  @override
  String get changeStop => 'Mudar de paragem';

  @override
  String get board => 'Próximos autocarros';

  @override
  String nextIn(int minutes) {
    return 'Próximo daqui a $minutes min';
  }

  @override
  String thenAt(String list) {
    return 'depois $list';
  }

  @override
  String get noBoard => 'Sem autocarros na próxima hora.';

  @override
  String get freshLive => 'Em tempo real';

  @override
  String get freshScheduled => 'Horário';

  @override
  String freshStale(int seconds) {
    return 'Sem dados em tempo real há $seconds s';
  }

  @override
  String get freshNoRealtime => 'Sem dados em tempo real';

  @override
  String get outOfHours => 'Fora do horário';

  @override
  String nextAt(String time) {
    return 'próximo $time';
  }

  @override
  String get noServiceToday => 'Sem serviço hoje';

  @override
  String get serviceHours => 'Horário';

  @override
  String get estimatedFare => 'Tarifa estimada';

  @override
  String get fareNotPublished => 'Tarifa não publicada';

  @override
  String get fareBase => 'Bilhete';

  @override
  String get fareTransfer => 'Transbordo';

  @override
  String get fareEstimatedNote =>
      'Estimativa com a tarifa configurada para a cidade; pode variar.';

  @override
  String get sortFastest => 'Mais rápido';

  @override
  String get sortFewerTransfers => 'Menos transbordos';

  @override
  String get sortLessWalking => 'Menos a pé';

  @override
  String get sortCheapest => 'Mais barato';

  @override
  String get sortEarliest => 'Partida mais próxima';

  @override
  String get sortBy => 'Ordenar';

  @override
  String get favHome => 'Casa';

  @override
  String get favWork => 'Trabalho';

  @override
  String get favCustom => 'Outro';

  @override
  String get saveAs => 'Guardar como';

  @override
  String get recentTrips => 'Viagens recentes';

  @override
  String get clearRecent => 'Apagar';

  @override
  String get setHome => 'Definir Casa';

  @override
  String get setWork => 'Definir Trabalho';

  @override
  String get chooseIcon => 'Escolhe um ícone';

  @override
  String get saveFavorite => 'Guardar favorito';

  @override
  String get favoriteName => 'Nome';

  @override
  String get updateRequired => 'Atualiza a app';

  @override
  String get updateRequiredBody =>
      'Esta versão já não é compatível. Atualiza para continuares a usar o OpenTransit.';

  @override
  String get updateAction => 'Atualizar';

  @override
  String get updateOpenFailed =>
      'Não foi possível abrir a loja. Procura-nos como «opentransit» para atualizar.';

  @override
  String get maintenanceTitle => 'Em manutenção';

  @override
  String get maintenanceBody =>
      'Estamos a fazer melhorias. Tenta de novo dentro de uns minutos.';

  @override
  String get checkAgain => 'Tentar de novo';

  @override
  String get shareCopied => 'Ligação copiada';

  @override
  String get shareTrip => 'Partilhar viagem';

  @override
  String get copyLink => 'Copiar ligação';

  @override
  String get openInWeb => 'Abrir no site';

  @override
  String get startTrip => 'Iniciar viagem';

  @override
  String get stopTrip => 'Terminar';

  @override
  String get currentLeg => 'Troço atual';

  @override
  String get nextStopIsYours => 'A próxima paragem é a tua';

  @override
  String getOffAt(String stop) {
    return 'Sai em $stop';
  }

  @override
  String get followAlongHint =>
      'Avisamos-te quando te aproximares da tua paragem de saída.';

  @override
  String progressLabel(int done, int total) {
    return 'Troço $done de $total';
  }

  @override
  String get arrived => 'Chegaste!';

  @override
  String distanceToStop(String distance) {
    return '$distance até à tua paragem';
  }

  @override
  String get followAlongLocationNeeded =>
      'Precisamos da tua localização para seguir a viagem.';

  @override
  String get poiLayer => 'Serviços nas estações';

  @override
  String get poiBikeParking => 'Estacionamento de bicicletas';

  @override
  String get poiToilets => 'Casas de banho';

  @override
  String get poiAtm => 'Multibanco';

  @override
  String get poiHealth => 'Posto de saúde';

  @override
  String get poiLibrary => 'Biblioteca';

  @override
  String get poiOther => 'Serviço';

  @override
  String get accessibilityUnverified => 'Dado do feed não verificado';

  @override
  String get accessibilityNotAccessible => 'Não acessível';

  @override
  String get accessibilityUnknown => 'Sem informação de acessibilidade';

  @override
  String accessibilitySource(String source) {
    return 'Fonte: $source';
  }

  @override
  String get accessibilityVerified => 'Verificado';

  @override
  String get nearYou => 'Perto de ti';

  @override
  String get bikeToStation => 'Ir de bicicleta até à estação';

  @override
  String get reportProblem => 'Reportar um problema';

  @override
  String get pqrs => 'Reclamações';

  @override
  String get openExternal => 'Abrir ligação';

  @override
  String get rechargeCard => 'Carregar o cartão';

  @override
  String get routesSearchHint => 'Procurar carreira (p. ex. 728)';

  @override
  String get station => 'Estação';

  @override
  String get etaLegend => '≤5 · ≤10 · ≤15 min';

  @override
  String get live => 'Em tempo real';

  @override
  String get allRoutes => 'Todas as carreiras';

  @override
  String get noRoutes => 'Não encontrámos carreiras.';

  @override
  String minutesOnly(int minutes) {
    return '$minutes min';
  }

  @override
  String get now2 => 'Já';

  @override
  String vehicleAgo(int seconds) {
    return 'há $seconds s';
  }

  @override
  String get goToStop => 'Ir para a paragem';

  @override
  String get showOnMap => 'Ver no mapa';

  @override
  String get selectRoute => 'Seleciona uma carreira';

  @override
  String get layers => 'Camadas';

  @override
  String get layerLive => 'Autocarros em tempo real';

  @override
  String get layerLiveHint => 'Aparecem ao aproximar o mapa (zoom 14+)';

  @override
  String get layerPois => 'Serviços';

  @override
  String get layerNetwork => 'Rede de carreiras';

  @override
  String get nearYouTitle => 'Perto de ti';

  @override
  String get zoomInForBuses => 'Aproxima o mapa para ver os autocarros';

  @override
  String get actionPlan => 'Planear viagem';

  @override
  String get actionLocate => 'Localiza o autocarro';

  @override
  String get actionRoutes => 'Procurar carreira';

  @override
  String get timeNow => 'Agora';

  @override
  String get timeSheetTitle => 'Quando viajas?';

  @override
  String get modeBike => 'Bicicleta';

  @override
  String get modeWalkShort => 'A pé';

  @override
  String routesCount(int count) {
    return 'Carreiras · $count';
  }

  @override
  String get viewOnMapAction => 'Ver no mapa';

  @override
  String get noNearbyStops => 'Não há paragens perto deste ponto';

  @override
  String get done => 'Feito';

  @override
  String get layerNetworkHint => 'Traçados da rede principal';

  @override
  String get layerNetworkZonalHint => 'Centenas de traçados sobrepostos';

  @override
  String thenTimes(String times) {
    return 'depois $times min';
  }

  @override
  String get modeBikeShare => 'Bicicleta partilhada';

  @override
  String rentalPickup(String station) {
    return 'Levanta uma bicicleta em $station';
  }

  @override
  String rentalDropoff(String station) {
    return 'Deixa a bicicleta em $station';
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
      other: '$count bicicletas disponíveis',
      one: '1 bicicleta disponível',
      zero: 'Sem bicicletas disponíveis',
    );
    return '$_temp0';
  }

  @override
  String docksAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count docas livres',
      one: '1 doca livre',
      zero: 'Sem docas livres',
    );
    return '$_temp0';
  }

  @override
  String bikesShort(int count) {
    return '$count bicicletas';
  }

  @override
  String ebikesShort(int count) {
    return '$count elétricas';
  }

  @override
  String docksShort(int count) {
    return '$count docas';
  }

  @override
  String openApp(String name) {
    return 'Abrir $name';
  }

  @override
  String get layerBikeShare => 'Bicicletas partilhadas';

  @override
  String get layerBikeShareHint =>
      'Estações e bicicletas disponíveis (zoom 14+)';

  @override
  String get rentalStation => 'Estação de bicicletas';

  @override
  String get howToGetThere => 'Como chegar';

  @override
  String noRentalData(String name) {
    return 'Sem dados de $name agora';
  }

  @override
  String get rentalNotRenting => 'Não disponibiliza bicicletas neste momento';

  @override
  String get rentalNotReturning => 'Não recebe bicicletas neste momento';

  @override
  String rentalPriceLine(String amount, String label) {
    return '≈ $amount · $label';
  }

  @override
  String get rentalDockHint =>
      'Ao chegares, deixa a bicicleta presa na doca da estação.';

  @override
  String sharedBikeOf(String name) {
    return 'Bicicleta partilhada · $name';
  }

  @override
  String get electricBike => 'elétrica';

  @override
  String get rentalUnavailableHint => 'Sem dados de estações nesta zona.';

  @override
  String get modeScooter => 'Trotinete';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'Atualizado há $minutes min';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'Atualizado há $hours h';
  }

  @override
  String get modeOnDemand => 'Táxi / app';

  @override
  String get onDemandTaxi => 'Táxi';

  @override
  String get onDemandRidehail => 'App de TVDE';

  @override
  String get priceInApp => 'Preço na app';

  @override
  String get requestRide => 'Pedir';

  @override
  String get requestVehicle => 'Pede o teu veículo';

  @override
  String requestVehicleTo(String place) {
    return 'Pede o teu veículo para $place';
  }

  @override
  String onDemandRideLine(String duration, String distance) {
    return '$duration · $distance de carro';
  }

  @override
  String get chooseProvider => 'Escolhe como pedir';

  @override
  String get recommended => 'Recomendado';

  @override
  String waitMinutes(int minutes) {
    return '$minutes min de espera';
  }

  @override
  String tariffSource(String source) {
    return 'Estimativa segundo $source · o taxímetro é que manda';
  }

  @override
  String get onDemandToHere => 'Chegar de táxi / app';

  @override
  String get onDemandNoProviders =>
      'Não há táxis nem apps de TVDE configurados nesta cidade.';

  @override
  String get onDemandOpenFailed =>
      'Não foi possível abrir a app do fornecedor.';

  @override
  String get taxiToBus => 'Táxi → Autocarro';

  @override
  String get onDemandOffline =>
      'Não foi possível obter a estimativa da viagem.';

  @override
  String requestProviderPriced(String name, String price) {
    return 'Pedir $name · $price';
  }

  @override
  String requestWithProvider(String name) {
    return 'Pedir com $name';
  }

  @override
  String get orRequestWith => 'Ou pede com:';

  @override
  String get seePrices => 'Ver preços';

  @override
  String get hidePrices => 'Ocultar preços';

  @override
  String onDemandDestination(String place) {
    return 'Para $place';
  }

  @override
  String get viewFullRoute => 'Ver carreira completa';

  @override
  String get locateNoLive =>
      'Sem autocarros em tempo real nesta carreira agora';

  @override
  String locateNoneComing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autocarros em circulação',
      one: '1 autocarro em circulação',
    );
    return '$_temp0 · nenhum vem para esta paragem ainda';
  }

  @override
  String locateComing(int count, int coming) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autocarros em circulação',
      one: '1 autocarro em circulação',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coming,
      locale: localeName,
      other: '$coming vêm',
      one: '1 vem',
    );
    return '$_temp0 · $_temp1 para esta paragem';
  }

  @override
  String get modeSharedShort => 'Partilhada';

  @override
  String get modeOnDemandShort => 'Táxi/app';

  @override
  String get stateOn => 'ativado';

  @override
  String get stateOff => 'desativado';

  @override
  String leaveIn(int minutes) {
    return 'Sai daqui a $minutes min';
  }

  @override
  String get leaveNow => 'Sai agora';

  @override
  String get departed => 'Já partiu';

  @override
  String get refreshResults => 'Atualizar';

  @override
  String get scenarioFastest => 'Mais rápido';

  @override
  String get scenarioLessWalking => 'Menos a pé';

  @override
  String get scenarioFewerTransfers => 'Menos transbordos';

  @override
  String get scenarioCheapest => 'Mais barato';

  @override
  String get scenarioBike => 'De bicicleta';

  @override
  String get scenarioOnDemand => 'Táxi / app';

  @override
  String get sortByScenario => 'Por cenário';

  @override
  String get orderMenu => 'Ordenar';

  @override
  String moreOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count opções',
      one: 'mais 1 opção',
    );
    return '$_temp0';
  }

  @override
  String get nextDeparturesHere => 'Próximas partidas aqui';

  @override
  String get retimed => 'Reajustado';

  @override
  String get retimedHint => 'Horas ajustadas à partida escolhida';

  @override
  String andThenTimes(String times) {
    return 'e daqui a $times min';
  }

  @override
  String get noStopsNearbyWalk => 'Não há paragens a 30 min a pé';

  @override
  String get noBoardContext => 'Não há partidas próximas nesta paragem';

  @override
  String get noLiveScheduledBelow =>
      'Sem autocarros em tempo real nesta carreira agora · horário programado abaixo';

  @override
  String get offlineBar => 'Sem ligação · a mostrar dados guardados';

  @override
  String get backOnlineBar => 'Ligação restabelecida';

  @override
  String staleBar(int seconds) {
    return 'Dados em tempo real com atraso · há $seconds s';
  }

  @override
  String get privacyTitle => 'Privacidade';

  @override
  String get analyticsToggle => 'Partilhar estatísticas anónimas de utilização';

  @override
  String get analyticsExplain =>
      'Ajuda a melhorar os transportes da tua cidade: só dados anónimos e agregados, nunca a tua localização exata.';

  @override
  String get analyticsClear => 'Apagar as minhas estatísticas';

  @override
  String get analyticsCleared =>
      'Estatísticas apagadas e identificador renovado';

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get agencyPrivacyPolicy => 'Política de privacidade do operador';

  @override
  String get commuteToWork => 'Ir para o trabalho';

  @override
  String get commuteToHome => 'Ir para casa';

  @override
  String get commuteInvert => 'Inverter';

  @override
  String get commuteSeeRoute => 'Ver percurso';

  @override
  String get commuteNoPlan => 'Sem opções agora';

  @override
  String get commuteDetour => 'Percurso com desvio · Replanear';

  @override
  String get commuteSetup =>
      'Guarda Casa e Trabalho para veres o teu trajeto aqui';

  @override
  String get departuresSheetTitle => 'Quando partir';

  @override
  String get departuresButton => 'Partidas';

  @override
  String get forecastRecommended => 'Melhor opção';

  @override
  String forecastGap(String time) {
    return 'Depois não há serviço até às $time';
  }

  @override
  String get forecastEmpty => 'Não há mais partidas nesta faixa horária';

  @override
  String forecastArrive(String time) {
    return 'chega $time';
  }

  @override
  String get forecastPickThis => 'Planear a esta hora';

  @override
  String get routeAlertsTitle => 'Avisos desta carreira';

  @override
  String get routeAlertsAlways => 'Sempre';

  @override
  String get routeAlertsWeekdays => 'Só dias úteis';

  @override
  String get routeAlertsWorkHours => 'Só horário de trabalho';

  @override
  String get routeAlertsNever => 'Nunca';

  @override
  String get routeAlertsOn => 'Avisos ativados';

  @override
  String get routeAlertsOff => 'Avisos desativados';

  @override
  String routeAlertNotificationTitle(String route) {
    return '$route: novidade na tua carreira';
  }

  @override
  String get quickGo => 'GO rápido';

  @override
  String busesOnRoute(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autocarros em circulação',
      one: '1 autocarro em circulação',
      zero: 'Sem autocarros em tempo real',
    );
    return '$_temp0';
  }

  @override
  String get goReceiptTitle => 'Viagem terminada';

  @override
  String get goReceiptPlanned => 'Planeado';

  @override
  String get goReceiptActual => 'Real';

  @override
  String get goReceiptDistance => 'Distância';

  @override
  String get goReceiptModes => 'Modos';

  @override
  String get goReceiptCost => 'Custo estimado';

  @override
  String get goReceiptCo2 => 'CO₂ evitado vs. carro';

  @override
  String get goReceiptClose => 'Feito';

  @override
  String get goOffRoute => 'Parece que saíste do percurso';

  @override
  String get goReplan => 'Replanear';

  @override
  String get goRecenter => 'Voltar à minha localização';

  @override
  String get goReplanFailed =>
      'Não foi possível recalcular. Continuas no percurso anterior.';

  @override
  String get goDismiss => 'Continuar assim';

  @override
  String get goNotificationTitle => 'Viagem em curso';

  @override
  String goNotificationBody(String stop, int minutes, String time) {
    return 'Sai em $stop · $minutes min · chegas $time';
  }

  @override
  String get goLocationWhy =>
      'Usamos a tua localização só enquanto a viagem durar, para te avisar quando sair.';

  @override
  String get shareTripCreating => 'A criar a ligação…';

  @override
  String get shareTripCopied => 'Ligação copiada';

  @override
  String get shareTripStop => 'Deixar de partilhar';

  @override
  String get shareTripStopped => 'A ligação já não está ativa';

  @override
  String get shareTripFailed => 'Não foi possível criar a ligação';

  @override
  String get shareTripActive => 'A partilhar em tempo real';

  @override
  String get ok => 'Entendido';

  @override
  String get nearMeTitle => 'Perto de mim';

  @override
  String get nearMeEntry => 'Autocarros perto';

  @override
  String get nearMeLoading => 'A procurar autocarros…';

  @override
  String nearMeCount(int count, String radius) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autocarros em $radius',
      one: '1 autocarro em $radius',
      zero: 'Sem autocarros em $radius',
    );
    return '$_temp0';
  }

  @override
  String nearMeEmpty(String radius) {
    return 'Não há autocarros em $radius';
  }

  @override
  String nearMeWiden(String radius) {
    return 'Alargar a $radius';
  }

  @override
  String nearMeAt(String distance) {
    return 'a $distance';
  }

  @override
  String get nearMeApproaching => 'A aproximar-se';

  @override
  String get nearMeLeaving => 'A afastar-se';

  @override
  String get nearMeNeedsLocation =>
      'Precisamos da tua localização para te mostrar os autocarros à tua volta.';

  @override
  String get backToMyLocation => 'Voltar à minha localização';

  @override
  String get assistantTitle => 'Pergunta-me';

  @override
  String get assistantIntro =>
      'Respondo com os dados da cidade: planeio viagens, vejo as próximas partidas e verifico desvios. Se não tiver como saber, digo-te.';

  @override
  String get assistantPlaceholder =>
      'Pergunta por uma carreira ou um autocarro';

  @override
  String get assistantSend => 'Enviar';

  @override
  String get assistantStop => 'Parar';

  @override
  String get assistantClose => 'Fechar';

  @override
  String get assistantThinking => 'A pensar…';

  @override
  String assistantNotice(String provider) {
    return 'As tuas perguntas são enviadas para $provider para redigir a resposta. Não enviamos a tua localização exata nem guardamos a conversa.';
  }

  @override
  String get assistantSuggestion1 => 'Como chego à Baixa?';

  @override
  String get assistantSuggestion2 => 'A que horas passa o próximo autocarro?';

  @override
  String get assistantSuggestion3 => 'Há desvios hoje?';

  @override
  String get assistantToolPlanTrip => 'A procurar percursos…';

  @override
  String get assistantToolFindPlace => 'A procurar o lugar…';

  @override
  String get assistantToolNextDepartures => 'A consultar as próximas partidas…';

  @override
  String get assistantToolLocateBus => 'A localizar o autocarro…';

  @override
  String get assistantToolServiceAlerts => 'A verificar desvios…';

  @override
  String get assistantToolFareEstimate => 'A calcular a tarifa…';

  @override
  String get assistantToolNearbyStops => 'A procurar paragens perto…';

  @override
  String get assistantToolBikeStations => 'A procurar bicicletas…';

  @override
  String get assistantToolVehiclesNear => 'A procurar autocarros perto…';

  @override
  String get assistantToolRouteInfo => 'A consultar a carreira…';

  @override
  String get assistantErrBudget =>
      'O assistente atingiu o seu orçamento de hoje. Volta amanhã ou usa o planeador.';

  @override
  String get assistantErrDisabled =>
      'O assistente não está disponível nesta cidade.';

  @override
  String get assistantErrRate =>
      'Estás a ir muito depressa. Espera um momento e volta a perguntar.';

  @override
  String get assistantErrUpstream =>
      'Não consegui responder agora. Tenta de novo.';

  @override
  String get assistantNewConversation => 'Nova conversa';

  @override
  String get assistantNewConfirm =>
      'Começar uma conversa nova? Apaga-se o que perguntaste até agora.';

  @override
  String get assistantNewConfirmCta => 'Começar de novo';

  @override
  String get cancel => 'Cancelar';

  @override
  String get pickOnMapHint => 'Move o mapa para escolher o ponto';

  @override
  String get pickOnMapSearching => 'A procurar a morada…';

  @override
  String get pickOnMapConfirmOrigin => 'Confirmar origem';

  @override
  String get pickOnMapConfirmDestination => 'Confirmar destino';

  @override
  String get dragPinsHint =>
      'Arrasta os pinos para mover a origem ou o destino';

  @override
  String get replanning => 'A recalcular a viagem…';

  @override
  String get replanFailed => 'Não foi possível recalcular a viagem';

  @override
  String get placeTypeStation => 'Estação';

  @override
  String get placeTypeStop => 'Paragem';

  @override
  String get placeTypeAddress => 'Morada';

  @override
  String get placeTypeStreet => 'Rua';

  @override
  String get placeTypePlace => 'Lugar';

  @override
  String get placeOptions => 'Opções do lugar';

  @override
  String get modeParkRide => 'Carro + transportes';

  @override
  String get modeParkRideShort => 'Carro+autocarro';

  @override
  String get scenarioParkRide => 'Carro + transportes';

  @override
  String get layerParking => 'Estacionamento pago';

  @override
  String get layerParkingHint =>
      'Zonas com lugares livres, segundo a última contagem (zoom 14+)';

  @override
  String get parkingZone => 'Zona de estacionamento pago';

  @override
  String get parkingOwnCar => 'O teu carro';

  @override
  String parkingLeaveCarAt(String place) {
    return 'Deixa o carro em $place';
  }

  @override
  String parkingSpaces(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lugares',
      one: '1 lugar',
    );
    return '$_temp0';
  }

  @override
  String parkingSpacesOf(int n, int total) {
    return '$n de $total lugares';
  }

  @override
  String get parkingUnknownSpaces => 'Lugares sem contagem';

  @override
  String get parkingFull => 'Sem lugares';

  @override
  String get parkingAllowedNow => 'Podes estacionar agora';

  @override
  String get parkingNotNow => 'Não é possível estacionar agora';

  @override
  String parkingUntil(String time) {
    return 'até às $time';
  }

  @override
  String get parkingNoCount => 'O operador não publica a contagem';

  @override
  String parkingFeeFor(int hours) {
    return 'Estacionamento $hours h';
  }

  @override
  String parkingThenWalk(String distance, String duration) {
    return 'Depois $distance a pé ($duration) até à paragem';
  }

  @override
  String get parkingContinueByTransit => 'Continuar em transportes públicos';

  @override
  String get tripsTitle => 'Viagens agendadas';

  @override
  String get tripsSettingsHint => 'Avisos na noite anterior e à hora de partir';

  @override
  String get tripsEmpty =>
      'Agenda uma viagem a partir de um resultado ou do teu trajeto Casa ⇄ Trabalho e avisamos-te quando partir.';

  @override
  String get tripsRefresh => 'Recalcular';

  @override
  String get scheduleTrip => 'Agendar viagem';

  @override
  String get scheduleTripHint =>
      'Avisamos-te na noite anterior com a hora de partida, 20 minutos antes com dados em tempo real, e à hora de partir.';

  @override
  String get scheduleArriveBy => 'Chegar às';

  @override
  String get scheduleDepartAt => 'Partir às';

  @override
  String get scheduleRepeat => 'Repetir';

  @override
  String get scheduleOnce => 'Uma vez';

  @override
  String get scheduleSave => 'Agendar';

  @override
  String get scheduleSaved =>
      'Feito. Avisamos-te na noite anterior e à hora de partir.';

  @override
  String get scheduleNotifDenied =>
      'Viagem guardada, mas sem permissão de notificações não podemos avisar-te.';

  @override
  String get tripWeekdays => 'Seg–Sex';

  @override
  String get tripDaily => 'Todos os dias';

  @override
  String get tripWeekend => 'Fim de semana';

  @override
  String tripOnceOn(String date) {
    return '$date';
  }

  @override
  String tripArriveAt(String time) {
    return 'chegar $time';
  }

  @override
  String tripDepartAt(String time) {
    return 'partir $time';
  }

  @override
  String tripLeaveAround(String time) {
    return 'Sai ~$time';
  }

  @override
  String get tripPlanning => 'A calcular a hora de partida…';

  @override
  String get tripPast => 'Já passou';

  @override
  String get tripDeleted => 'Viagem eliminada';

  @override
  String tripEveTitle(String to) {
    return 'Amanhã: $to';
  }

  @override
  String tripEveBody(String leave, String arrive, String routes) {
    return 'Sai às $leave para chegares às $arrive · $routes';
  }

  @override
  String tripRefineTitle(String leave) {
    return 'Sai às $leave';
  }

  @override
  String tripRefineBody(String routes, String arrive) {
    return '$routes · chegas às $arrive';
  }

  @override
  String get tripLeaveTitle => 'Está na hora de sair';

  @override
  String tripLeaveBody(String to, String routes, String arrive) {
    return 'Para $to · $routes · chegas às $arrive';
  }

  @override
  String get remindersPermissionOk => 'Avisos permitidos';

  @override
  String get remindersPermissionUnknown =>
      'A verificar a permissão de notificações…';

  @override
  String get remindersPermissionDenied =>
      'As notificações estão desativadas para o opentransit: os avisos são agendados, mas o telemóvel não os mostra.';

  @override
  String get remindersOpenSettings => 'Permitir notificações';

  @override
  String get remindersTest => 'Testar aviso';

  @override
  String get remindersTestScheduled =>
      'Recebes um aviso de teste dentro de 10 segundos.';

  @override
  String get remindersTestTitle => 'Aviso de teste';

  @override
  String get remindersTestBody =>
      'É assim que vão aparecer os teus lembretes de viagem.';

  @override
  String remindersArmed(String kinds) {
    return 'Avisos ativos: $kinds';
  }

  @override
  String get remindersEve => 'noite anterior';

  @override
  String get remindersLeave => 'hora de partir';

  @override
  String get remindersNone =>
      'Sem avisos ativos — verifica a permissão de notificações';
}
