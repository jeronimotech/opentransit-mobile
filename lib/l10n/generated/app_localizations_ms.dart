// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get appTitle => 'OpenTransit';

  @override
  String get chooseCity => 'Pilih bandar anda';

  @override
  String get detectCity => 'Kesan bandar saya';

  @override
  String get detectingCity => 'Mencari bandar anda…';

  @override
  String cityDetected(String city) {
    return 'Anda berada di $city';
  }

  @override
  String get cityNotCovered =>
      'Kawasan anda belum dilindungi. Pilih bandar daripada senarai.';

  @override
  String get cityDetectFailed =>
      'Kami tidak dapat menggunakan lokasi anda. Pilih bandar daripada senarai.';

  @override
  String get chooseCitySubtitle =>
      'Rancang perjalanan pengangkutan awam dengan data terbuka dan masa nyata.';

  @override
  String get searchPlaceholder => 'Anda ke mana?';

  @override
  String get planTrip => 'Rancang perjalanan';

  @override
  String get fromLabel => 'Asal';

  @override
  String get toLabel => 'Destinasi';

  @override
  String get myLocation => 'Lokasi saya';

  @override
  String get chooseOnMap => 'Pilih di peta';

  @override
  String get departAt => 'Bertolak pada';

  @override
  String get arriveBy => 'Tiba sebelum';

  @override
  String get now => 'Sekarang';

  @override
  String get wheelchair => 'Mesra kerusi roda';

  @override
  String get modes => 'Mod';

  @override
  String get searchAction => 'Cari';

  @override
  String get results => 'Keputusan';

  @override
  String get noItineraries =>
      'Kami tidak menemui itinerari untuk perjalanan ini. Cuba waktu lain atau tambah jarak berjalan kaki.';

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pertukaran',
      one: '1 pertukaran',
      zero: 'Tanpa pertukaran',
    );
    return '$_temp0';
  }

  @override
  String walkDistance(int meters) {
    return '$meters m berjalan kaki';
  }

  @override
  String get itinerary => 'Itinerari';

  @override
  String get departures => 'Perlepasan seterusnya';

  @override
  String get noDepartures =>
      'Tiada perlepasan berjadual dalam sejam akan datang.';

  @override
  String get realtime => 'Langsung';

  @override
  String get scheduled => 'Berjadual';

  @override
  String get canceled => 'Dibatalkan';

  @override
  String delayedBy(int minutes) {
    return 'Lewat $minutes min';
  }

  @override
  String earlyBy(int minutes) {
    return 'Awal $minutes min';
  }

  @override
  String get onTime => 'Tepat pada masa';

  @override
  String get alerts => 'Makluman';

  @override
  String get noAlerts => 'Tiada makluman aktif.';

  @override
  String get favorites => 'Kegemaran';

  @override
  String get noFavorites =>
      'Simpan hentian, laluan dan tempat supaya mudah diakses.';

  @override
  String get settings => 'Tetapan';

  @override
  String get city => 'Bandar';

  @override
  String get language => 'Bahasa';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Cerah';

  @override
  String get themeDark => 'Gelap';

  @override
  String get accessibility => 'Kebolehaksesan';

  @override
  String get wheelchairPref => 'Utamakan laluan mesra kerusi roda';

  @override
  String get liveVehicles => 'Kenderaan langsung';

  @override
  String get nearbyStops => 'Hentian berdekatan';

  @override
  String get retry => 'Cuba lagi';

  @override
  String get errorGeneric =>
      'Ada yang tidak kena. Semak sambungan anda dan cuba lagi.';

  @override
  String get errorOffline => 'Tiada sambungan ke pelayan.';

  @override
  String get routes => 'Laluan';

  @override
  String get stops => 'Hentian';

  @override
  String get stop => 'Hentian';

  @override
  String get route => 'Laluan';

  @override
  String get viewOnMap => 'Lihat di peta';

  @override
  String get share => 'Kongsi';

  @override
  String get addFavorite => 'Simpan ke kegemaran';

  @override
  String get removeFavorite => 'Buang daripada kegemaran';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHm(int hours, int minutes) {
    return '$hours j $minutes min';
  }

  @override
  String get walkSteps => 'Arahan berjalan kaki';

  @override
  String intermediateStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hentian perantaraan',
      one: '1 hentian perantaraan',
      zero: 'Tiada hentian perantaraan',
    );
    return '$_temp0';
  }

  @override
  String updatedAgo(int seconds) {
    return 'Dikemas kini $seconds s yang lalu';
  }

  @override
  String vehiclesCount(int count) {
    return '$count kenderaan';
  }

  @override
  String get swap => 'Tukar asal dan destinasi';

  @override
  String get places => 'Tempat';

  @override
  String get tapToSetPlace => 'Ketik peta untuk memilih titik';

  @override
  String get longPressHint => 'Tekan lama pada peta untuk menetapkan titik';

  @override
  String get setAsOrigin => 'Guna sebagai asal';

  @override
  String get setAsDestination => 'Guna sebagai destinasi';

  @override
  String get home => 'Utama';

  @override
  String get about => 'Tentang';

  @override
  String get version => 'Versi';

  @override
  String get dataSource => 'Sumber data';

  @override
  String get mockMode => 'Mod demo (data contoh)';

  @override
  String get direction => 'Arah';

  @override
  String stopsCount(int count) {
    return '$count hentian';
  }

  @override
  String towards(String headsign) {
    return 'Ke arah $headsign';
  }

  @override
  String walkTo(String place) {
    return 'Berjalan ke $place';
  }

  @override
  String rideTo(String place) {
    return 'Turun di $place';
  }

  @override
  String boardAt(String place) {
    return 'Naik di $place';
  }

  @override
  String arriveAt(String place) {
    return 'Tiba di $place';
  }

  @override
  String get moreOptions => 'Lebih banyak pilihan';

  @override
  String get walkingDistance => 'Jarak maksimum berjalan kaki';

  @override
  String get changeCity => 'Tukar bandar';

  @override
  String get loading => 'Memuatkan…';

  @override
  String inMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get arrivingNow => 'Sekarang';

  @override
  String get seeAlerts => 'Lihat makluman';

  @override
  String get affectedRoutes => 'Laluan terjejas';

  @override
  String get componentTrunk => 'Utama';

  @override
  String get componentFeeder => 'Pengantara';

  @override
  String get componentDual => 'Dwi';

  @override
  String get componentZonal => 'Zon';

  @override
  String get componentCable => 'Kabel';

  @override
  String get componentRail => 'Kereta api';

  @override
  String get componentTram => 'Trem';

  @override
  String get componentBus => 'Bas';

  @override
  String get componentOther => 'Lain-lain';

  @override
  String get modeWalk => 'Jalan kaki';

  @override
  String get modeBus => 'Bas';

  @override
  String get modeRail => 'Kereta api';

  @override
  String get modeSubway => 'LRT/MRT';

  @override
  String get modeTram => 'Trem';

  @override
  String get modeCableCar => 'Kereta kabel';

  @override
  String get modeBicycle => 'Basikal';

  @override
  String get modeCar => 'Kereta';

  @override
  String get modeFerry => 'Feri';

  @override
  String get modeTransit => 'Pengangkutan awam';

  @override
  String get locationDenied =>
      'Tiada kebenaran lokasi. Aktifkan dalam tetapan sistem.';

  @override
  String get reverseTrip => 'Terbalikkan perjalanan';

  @override
  String get openInPlanner => 'Buka dalam perancang';

  @override
  String get goHere => 'Pergi ke sini';

  @override
  String get leaveFrom => 'Bertolak dari sini';

  @override
  String get fromHere => 'Dari sini';

  @override
  String get accessible => 'Mesra kerusi roda';

  @override
  String get hubTitle => 'Apa yang anda ingin semak?';

  @override
  String get tilePlan => 'Rancang perjalanan';

  @override
  String get tileLocate => 'Jejak bas anda';

  @override
  String get tileNearby => 'Hentian berdekatan';

  @override
  String get tileRoutes => 'Cari laluan';

  @override
  String get tileLive => 'Bas langsung';

  @override
  String get tileAlerts => 'Makluman';

  @override
  String get tileFavorites => 'Kegemaran';

  @override
  String get nearbyCardTitle => 'Stesen dan hentian berdekatan';

  @override
  String get services => 'Perkhidmatan';

  @override
  String get messagesOfInterest => 'Mesej penting';

  @override
  String get dismiss => 'Sembunyikan';

  @override
  String get seeAll => 'Lihat semua';

  @override
  String get locateTitle => 'Jejak bas anda';

  @override
  String get locateStep1 => 'Pilih stesen atau hentian';

  @override
  String get locateStep2 => 'Pilih laluan';

  @override
  String get locateNext => 'Bas seterusnya';

  @override
  String get sourceLive => 'Langsung';

  @override
  String get sourceScheduled => 'Mengikut jadual';

  @override
  String get sourceEstimated => 'Anggaran';

  @override
  String stopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hentian',
      one: '1 hentian',
    );
    return '$_temp0';
  }

  @override
  String get noBuses => 'Tiada bas terdekat untuk laluan ini.';

  @override
  String get searchStopHint => 'Cari stesen atau hentian';

  @override
  String get changeStop => 'Tukar hentian';

  @override
  String get board => 'Bas seterusnya';

  @override
  String nextIn(int minutes) {
    return 'Seterusnya dalam $minutes min';
  }

  @override
  String thenAt(String list) {
    return 'kemudian $list';
  }

  @override
  String get noBoard => 'Tiada bas dalam sejam akan datang.';

  @override
  String get freshLive => 'Langsung';

  @override
  String get freshScheduled => 'Berjadual';

  @override
  String freshStale(int seconds) {
    return 'Tiada data langsung sejak $seconds s yang lalu';
  }

  @override
  String get freshNoRealtime => 'Tiada data langsung';

  @override
  String get outOfHours => 'Di luar waktu operasi';

  @override
  String nextAt(String time) {
    return 'seterusnya $time';
  }

  @override
  String get noServiceToday => 'Tiada perkhidmatan hari ini';

  @override
  String get serviceHours => 'Waktu operasi';

  @override
  String get estimatedFare => 'Anggaran tambang';

  @override
  String get fareNotPublished => 'Tambang tidak diterbitkan';

  @override
  String get fareBase => 'Tambang asas';

  @override
  String get fareTransfer => 'Pertukaran';

  @override
  String get fareEstimatedNote =>
      'Anggaran mengikut tambang yang ditetapkan untuk bandar ini; mungkin berbeza.';

  @override
  String get sortFastest => 'Paling pantas';

  @override
  String get sortFewerTransfers => 'Paling sedikit pertukaran';

  @override
  String get sortLessWalking => 'Kurang berjalan';

  @override
  String get sortCheapest => 'Paling jimat';

  @override
  String get sortEarliest => 'Berlepas paling awal';

  @override
  String get sortBy => 'Susun';

  @override
  String get favHome => 'Rumah';

  @override
  String get favWork => 'Tempat kerja';

  @override
  String get favCustom => 'Lain';

  @override
  String get saveAs => 'Simpan sebagai';

  @override
  String get recentTrips => 'Perjalanan terkini';

  @override
  String get clearRecent => 'Padam';

  @override
  String get setHome => 'Tetapkan Rumah';

  @override
  String get setWork => 'Tetapkan Tempat kerja';

  @override
  String get chooseIcon => 'Pilih ikon';

  @override
  String get saveFavorite => 'Simpan kegemaran';

  @override
  String get favoriteName => 'Nama';

  @override
  String get updateRequired => 'Kemas kini aplikasi';

  @override
  String get updateRequiredBody =>
      'Versi ini tidak lagi disokong. Kemas kini untuk terus menggunakan OpenTransit.';

  @override
  String get updateAction => 'Kemas kini';

  @override
  String get updateOpenFailed =>
      'Tidak dapat membuka gedung aplikasi. Cari «opentransit» untuk mengemas kini.';

  @override
  String get maintenanceTitle => 'Dalam penyelenggaraan';

  @override
  String get maintenanceBody =>
      'Kami sedang membuat penambahbaikan. Cuba lagi dalam beberapa minit.';

  @override
  String get checkAgain => 'Cuba lagi';

  @override
  String get shareCopied => 'Pautan disalin';

  @override
  String get shareTrip => 'Kongsi perjalanan';

  @override
  String get copyLink => 'Salin pautan';

  @override
  String get openInWeb => 'Buka di web';

  @override
  String get startTrip => 'Mula perjalanan';

  @override
  String get stopTrip => 'Tamat';

  @override
  String get currentLeg => 'Peringkat semasa';

  @override
  String get nextStopIsYours => 'Hentian seterusnya ialah hentian anda';

  @override
  String getOffAt(String stop) {
    return 'Turun di $stop';
  }

  @override
  String get followAlongHint =>
      'Kami akan beritahu anda apabila hampir dengan hentian untuk turun.';

  @override
  String progressLabel(int done, int total) {
    return 'Peringkat $done daripada $total';
  }

  @override
  String get arrived => 'Anda telah tiba!';

  @override
  String distanceToStop(String distance) {
    return '$distance ke hentian anda';
  }

  @override
  String get followAlongLocationNeeded =>
      'Kami perlukan lokasi anda untuk mengikuti perjalanan.';

  @override
  String get poiLayer => 'Kemudahan di stesen';

  @override
  String get poiBikeParking => 'Parkir basikal';

  @override
  String get poiToilets => 'Tandas';

  @override
  String get poiAtm => 'ATM';

  @override
  String get poiHealth => 'Pusat kesihatan';

  @override
  String get poiLibrary => 'Perpustakaan';

  @override
  String get poiOther => 'Kemudahan';

  @override
  String get accessibilityUnverified => 'Data suapan belum disahkan';

  @override
  String get accessibilityNotAccessible => 'Tidak mesra kerusi roda';

  @override
  String get accessibilityUnknown => 'Tiada maklumat kebolehaksesan';

  @override
  String accessibilitySource(String source) {
    return 'Sumber: $source';
  }

  @override
  String get accessibilityVerified => 'Disahkan';

  @override
  String get nearYou => 'Berdekatan anda';

  @override
  String get bikeToStation => 'Berbasikal ke stesen';

  @override
  String get reportProblem => 'Laporkan masalah';

  @override
  String get pqrs => 'Aduan';

  @override
  String get openExternal => 'Buka pautan';

  @override
  String get rechargeCard => 'Tambah nilai kad';

  @override
  String get routesSearchHint => 'Cari laluan (cth. 780)';

  @override
  String get station => 'Stesen';

  @override
  String get etaLegend => '≤5 · ≤10 · ≤15 min';

  @override
  String get live => 'Langsung';

  @override
  String get allRoutes => 'Semua laluan';

  @override
  String get noRoutes => 'Kami tidak menemui laluan.';

  @override
  String minutesOnly(int minutes) {
    return '$minutes min';
  }

  @override
  String get now2 => 'Kini';

  @override
  String vehicleAgo(int seconds) {
    return '$seconds s yang lalu';
  }

  @override
  String get goToStop => 'Ke hentian';

  @override
  String get showOnMap => 'Lihat di peta';

  @override
  String get selectRoute => 'Pilih laluan';

  @override
  String get layers => 'Lapisan';

  @override
  String get layerLive => 'Bas langsung';

  @override
  String get layerLiveHint => 'Dipaparkan apabila peta dizum (zum 14+)';

  @override
  String get layerPois => 'Kemudahan';

  @override
  String get layerNetwork => 'Rangkaian laluan';

  @override
  String get nearYouTitle => 'Berdekatan anda';

  @override
  String get zoomInForBuses => 'Zum masuk peta untuk melihat bas';

  @override
  String get actionPlan => 'Rancang perjalanan';

  @override
  String get actionLocate => 'Jejak bas anda';

  @override
  String get actionRoutes => 'Cari laluan';

  @override
  String get timeNow => 'Sekarang';

  @override
  String get timeSheetTitle => 'Bila anda bertolak?';

  @override
  String get modeBike => 'Basikal';

  @override
  String get modeWalkShort => 'Jalan kaki';

  @override
  String routesCount(int count) {
    return 'Laluan · $count';
  }

  @override
  String get viewOnMapAction => 'Lihat di peta';

  @override
  String get noNearbyStops => 'Tiada hentian berhampiran titik ini';

  @override
  String get done => 'Selesai';

  @override
  String get layerNetworkHint => 'Jajaran rangkaian utama';

  @override
  String get layerNetworkZonalHint => 'Ratusan jajaran bertindih';

  @override
  String thenTimes(String times) {
    return 'kemudian $times min';
  }

  @override
  String get modeBikeShare => 'Basikal awam';

  @override
  String rentalPickup(String station) {
    return 'Ambil basikal di $station';
  }

  @override
  String rentalDropoff(String station) {
    return 'Letak basikal di $station';
  }

  @override
  String rentalRide(String duration, String distance) {
    return 'Kayuh $duration · $distance';
  }

  @override
  String bikesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count basikal tersedia',
      one: '1 basikal tersedia',
      zero: 'Tiada basikal tersedia',
    );
    return '$_temp0';
  }

  @override
  String docksAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dok kosong',
      one: '1 dok kosong',
      zero: 'Tiada dok kosong',
    );
    return '$_temp0';
  }

  @override
  String bikesShort(int count) {
    return '$count basikal';
  }

  @override
  String ebikesShort(int count) {
    return '$count elektrik';
  }

  @override
  String docksShort(int count) {
    return '$count dok';
  }

  @override
  String openApp(String name) {
    return 'Buka $name';
  }

  @override
  String get layerBikeShare => 'Basikal awam';

  @override
  String get layerBikeShareHint => 'Stesen dan basikal tersedia (zum 14+)';

  @override
  String get rentalStation => 'Stesen basikal';

  @override
  String get howToGetThere => 'Cara ke sana';

  @override
  String noRentalData(String name) {
    return 'Tiada data $name sekarang';
  }

  @override
  String get rentalNotRenting => 'Tidak menyewakan basikal buat masa ini';

  @override
  String get rentalNotReturning => 'Tidak menerima basikal buat masa ini';

  @override
  String rentalPriceLine(String amount, String label) {
    return '≈ $amount · $label';
  }

  @override
  String get rentalDockHint =>
      'Setibanya, letak basikal berkunci di dok stesen.';

  @override
  String sharedBikeOf(String name) {
    return 'Basikal awam · $name';
  }

  @override
  String get electricBike => 'elektrik';

  @override
  String get rentalUnavailableHint => 'Tiada data stesen di kawasan ini.';

  @override
  String get modeScooter => 'Skuter';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'Dikemas kini $minutes min yang lalu';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'Dikemas kini $hours j yang lalu';
  }

  @override
  String get modeOnDemand => 'Teksi / e-hailing';

  @override
  String get onDemandTaxi => 'Teksi';

  @override
  String get onDemandRidehail => 'Aplikasi e-hailing';

  @override
  String get priceInApp => 'Harga dalam aplikasi';

  @override
  String get requestRide => 'Tempah';

  @override
  String get requestVehicle => 'Tempah kenderaan anda';

  @override
  String requestVehicleTo(String place) {
    return 'Tempah kenderaan anda ke $place';
  }

  @override
  String onDemandRideLine(String duration, String distance) {
    return '$duration · $distance dengan kereta';
  }

  @override
  String get chooseProvider => 'Pilih cara menempah';

  @override
  String get recommended => 'Disyorkan';

  @override
  String waitMinutes(int minutes) {
    return '$minutes min menunggu';
  }

  @override
  String tariffSource(String source) {
    return 'Anggaran mengikut $source · meter teksi yang menentukan';
  }

  @override
  String get onDemandToHere => 'Tiba dengan teksi / e-hailing';

  @override
  String get onDemandNoProviders =>
      'Tiada teksi atau aplikasi e-hailing ditetapkan di bandar ini.';

  @override
  String get onDemandOpenFailed => 'Tidak dapat membuka aplikasi penyedia.';

  @override
  String get taxiToBus => 'Teksi → Bas';

  @override
  String get onDemandOffline => 'Tidak dapat memperoleh anggaran perjalanan.';

  @override
  String requestProviderPriced(String name, String price) {
    return 'Tempah $name · $price';
  }

  @override
  String requestWithProvider(String name) {
    return 'Tempah dengan $name';
  }

  @override
  String get orRequestWith => 'Atau tempah dengan:';

  @override
  String get seePrices => 'Lihat harga';

  @override
  String get hidePrices => 'Sembunyikan harga';

  @override
  String onDemandDestination(String place) {
    return 'Ke $place';
  }

  @override
  String get viewFullRoute => 'Lihat laluan penuh';

  @override
  String get locateNoLive => 'Tiada bas langsung di laluan ini sekarang';

  @override
  String locateNoneComing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bas dalam laluan',
      one: '1 bas dalam laluan',
    );
    return '$_temp0 · belum ada yang menuju ke hentian ini';
  }

  @override
  String locateComing(int count, int coming) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bas dalam laluan',
      one: '1 bas dalam laluan',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coming,
      locale: localeName,
      other: '$coming menuju',
      one: '1 menuju',
    );
    return '$_temp0 · $_temp1 ke hentian ini';
  }

  @override
  String get modeSharedShort => 'Awam';

  @override
  String get modeOnDemandShort => 'Teksi/e-hailing';

  @override
  String get stateOn => 'diaktifkan';

  @override
  String get stateOff => 'dinyahaktifkan';

  @override
  String leaveIn(int minutes) {
    return 'Bertolak dalam $minutes min';
  }

  @override
  String get leaveNow => 'Bertolak sekarang';

  @override
  String get departed => 'Sudah berlepas';

  @override
  String get refreshResults => 'Kemas kini';

  @override
  String get scenarioFastest => 'Paling pantas';

  @override
  String get scenarioLessWalking => 'Kurang berjalan';

  @override
  String get scenarioFewerTransfers => 'Paling sedikit pertukaran';

  @override
  String get scenarioCheapest => 'Paling murah';

  @override
  String get scenarioBike => 'Berbasikal';

  @override
  String get scenarioOnDemand => 'Teksi / e-hailing';

  @override
  String get sortByScenario => 'Mengikut senario';

  @override
  String get orderMenu => 'Susun';

  @override
  String moreOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lagi pilihan',
      one: '1 lagi pilihan',
    );
    return '$_temp0';
  }

  @override
  String get nextDeparturesHere => 'Perlepasan seterusnya di sini';

  @override
  String get retimed => 'Masa dilaraskan';

  @override
  String get retimedHint => 'Masa dilaraskan mengikut perlepasan yang dipilih';

  @override
  String andThenTimes(String times) {
    return 'dan dalam $times min';
  }

  @override
  String get noStopsNearbyWalk => 'Tiada hentian dalam 30 min berjalan kaki';

  @override
  String get noBoardContext => 'Tiada perlepasan terdekat di hentian ini';

  @override
  String get noLiveScheduledBelow =>
      'Tiada bas langsung di laluan ini sekarang · jadual di bawah';

  @override
  String get offlineBar => 'Tiada sambungan · memaparkan data tersimpan';

  @override
  String get backOnlineBar => 'Sambungan dipulihkan';

  @override
  String staleBar(int seconds) {
    return 'Data langsung tertangguh · $seconds s yang lalu';
  }

  @override
  String get privacyTitle => 'Privasi';

  @override
  String get analyticsToggle => 'Kongsi statistik penggunaan tanpa nama';

  @override
  String get analyticsExplain =>
      'Bantu menambah baik pengangkutan bandar anda: hanya data tanpa nama dan agregat, tidak pernah lokasi tepat anda.';

  @override
  String get analyticsClear => 'Padam statistik saya';

  @override
  String get analyticsCleared => 'Statistik dipadam dan pengecam diperbaharui';

  @override
  String get privacyPolicy => 'Dasar privasi';

  @override
  String get agencyPrivacyPolicy => 'Dasar privasi pengendali';

  @override
  String get commuteToWork => 'Ke tempat kerja';

  @override
  String get commuteToHome => 'Ke rumah';

  @override
  String get commuteInvert => 'Terbalikkan';

  @override
  String get commuteSeeRoute => 'Lihat laluan';

  @override
  String get commuteNoPlan => 'Tiada pilihan sekarang';

  @override
  String get commuteDetour => 'Laluan dengan lencongan · Rancang semula';

  @override
  String get commuteSetup =>
      'Simpan Rumah dan Tempat kerja untuk melihat perjalanan harian anda di sini';

  @override
  String get departuresSheetTitle => 'Bila nak bertolak';

  @override
  String get departuresButton => 'Perlepasan';

  @override
  String get forecastRecommended => 'Pilihan terbaik';

  @override
  String forecastGap(String time) {
    return 'Selepas itu tiada perkhidmatan sehingga $time';
  }

  @override
  String get forecastEmpty => 'Tiada lagi perlepasan dalam tempoh ini';

  @override
  String forecastArrive(String time) {
    return 'tiba $time';
  }

  @override
  String get forecastPickThis => 'Rancang pada waktu ini';

  @override
  String get routeAlertsTitle => 'Makluman untuk laluan ini';

  @override
  String get routeAlertsAlways => 'Sentiasa';

  @override
  String get routeAlertsWeekdays => 'Hari bekerja sahaja';

  @override
  String get routeAlertsWorkHours => 'Waktu bekerja sahaja';

  @override
  String get routeAlertsNever => 'Tidak pernah';

  @override
  String get routeAlertsOn => 'Makluman diaktifkan';

  @override
  String get routeAlertsOff => 'Makluman dinyahaktifkan';

  @override
  String routeAlertNotificationTitle(String route) {
    return '$route: perkembangan terkini di laluan anda';
  }

  @override
  String get quickGo => 'GO pantas';

  @override
  String busesOnRoute(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bas dalam laluan',
      one: '1 bas dalam laluan',
      zero: 'Tiada bas langsung',
    );
    return '$_temp0';
  }

  @override
  String get goReceiptTitle => 'Perjalanan tamat';

  @override
  String get goReceiptPlanned => 'Dirancang';

  @override
  String get goReceiptActual => 'Sebenar';

  @override
  String get goReceiptDistance => 'Jarak';

  @override
  String get goReceiptModes => 'Mod';

  @override
  String get goReceiptCost => 'Anggaran kos';

  @override
  String get goReceiptCo2 => 'CO₂ dielakkan berbanding kereta';

  @override
  String get goReceiptClose => 'Selesai';

  @override
  String get goOffRoute => 'Nampaknya anda tersasar dari laluan';

  @override
  String get goReplan => 'Rancang semula';

  @override
  String get goRecenter => 'Kembali ke lokasi saya';

  @override
  String get goReplanFailed =>
      'Tidak dapat mengira semula. Anda masih di laluan sebelumnya.';

  @override
  String get goDismiss => 'Teruskan seperti biasa';

  @override
  String get goNotificationTitle => 'Perjalanan sedang berlangsung';

  @override
  String goNotificationBody(String stop, int minutes, String time) {
    return 'Turun di $stop · $minutes min · tiba $time';
  }

  @override
  String get goLocationWhy =>
      'Kami menggunakan lokasi anda hanya sepanjang perjalanan, untuk memberitahu bila anda perlu turun.';

  @override
  String get shareTripCreating => 'Mencipta pautan…';

  @override
  String get shareTripCopied => 'Pautan disalin';

  @override
  String get shareTripStop => 'Berhenti berkongsi';

  @override
  String get shareTripStopped => 'Pautan tidak lagi aktif';

  @override
  String get shareTripFailed => 'Tidak dapat mencipta pautan';

  @override
  String get shareTripActive => 'Berkongsi secara langsung';

  @override
  String get ok => 'Faham';

  @override
  String get nearMeTitle => 'Berhampiran saya';

  @override
  String get nearMeEntry => 'Bas berdekatan';

  @override
  String get nearMeLoading => 'Mencari bas…';

  @override
  String nearMeCount(int count, String radius) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bas dalam $radius',
      one: '1 bas dalam $radius',
      zero: 'Tiada bas dalam $radius',
    );
    return '$_temp0';
  }

  @override
  String nearMeEmpty(String radius) {
    return 'Tiada bas dalam $radius';
  }

  @override
  String nearMeWiden(String radius) {
    return 'Luaskan ke $radius';
  }

  @override
  String nearMeAt(String distance) {
    return '$distance dari sini';
  }

  @override
  String get nearMeApproaching => 'Menghampiri';

  @override
  String get nearMeLeaving => 'Menjauh';

  @override
  String get nearMeNeedsLocation =>
      'Kami perlukan lokasi anda untuk memaparkan bas di sekitar anda.';

  @override
  String get backToMyLocation => 'Kembali ke lokasi saya';

  @override
  String get assistantTitle => 'Tanya saya';

  @override
  String get assistantIntro =>
      'Saya menjawab dengan data bandar: merancang perjalanan, menyemak perlepasan seterusnya dan lencongan. Jika saya tidak tahu, saya akan beritahu anda.';

  @override
  String get assistantPlaceholder => 'Tanya tentang laluan atau bas';

  @override
  String get assistantSend => 'Hantar';

  @override
  String get assistantStop => 'Berhenti';

  @override
  String get assistantClose => 'Tutup';

  @override
  String get assistantThinking => 'Sedang berfikir…';

  @override
  String assistantNotice(String provider) {
    return 'Soalan anda dihantar ke $provider untuk menjana jawapan. Kami tidak menghantar lokasi tepat anda dan tidak menyimpan perbualan.';
  }

  @override
  String get assistantSuggestion1 => 'Bagaimana saya ke pusat bandar?';

  @override
  String get assistantSuggestion2 => 'Pukul berapa bas seterusnya?';

  @override
  String get assistantSuggestion3 => 'Ada lencongan hari ini?';

  @override
  String get assistantToolPlanTrip => 'Mencari laluan…';

  @override
  String get assistantToolFindPlace => 'Mencari tempat…';

  @override
  String get assistantToolNextDepartures => 'Menyemak perlepasan seterusnya…';

  @override
  String get assistantToolLocateBus => 'Menjejak bas…';

  @override
  String get assistantToolServiceAlerts => 'Menyemak lencongan…';

  @override
  String get assistantToolFareEstimate => 'Mengira tambang…';

  @override
  String get assistantToolNearbyStops => 'Mencari hentian berdekatan…';

  @override
  String get assistantToolBikeStations => 'Mencari basikal…';

  @override
  String get assistantToolVehiclesNear => 'Mencari bas berdekatan…';

  @override
  String get assistantToolRouteInfo => 'Menyemak laluan…';

  @override
  String get assistantErrBudget =>
      'Pembantu telah mencapai had belanjawan hari ini. Kembali esok atau gunakan perancang.';

  @override
  String get assistantErrDisabled => 'Pembantu tidak tersedia di bandar ini.';

  @override
  String get assistantErrRate =>
      'Anda terlalu pantas. Tunggu sebentar dan tanya semula.';

  @override
  String get assistantErrUpstream =>
      'Saya tidak dapat menjawab buat masa ini. Cuba lagi.';

  @override
  String get assistantNewConversation => 'Perbualan baharu';

  @override
  String get assistantNewConfirm =>
      'Mulakan perbualan baharu? Apa yang anda tanya setakat ini akan dipadam.';

  @override
  String get assistantNewConfirmCta => 'Mula semula';

  @override
  String get cancel => 'Batal';

  @override
  String get pickOnMapHint => 'Gerakkan peta untuk memilih titik';

  @override
  String get pickOnMapSearching => 'Mencari alamat…';

  @override
  String get pickOnMapConfirmOrigin => 'Sahkan asal';

  @override
  String get pickOnMapConfirmDestination => 'Sahkan destinasi';

  @override
  String get dragPinsHint => 'Seret pin untuk mengalihkan asal atau destinasi';

  @override
  String get replanning => 'Mengira semula perjalanan…';

  @override
  String get replanFailed => 'Tidak dapat mengira semula perjalanan';

  @override
  String get placeTypeStation => 'Stesen';

  @override
  String get placeTypeStop => 'Hentian';

  @override
  String get placeTypeAddress => 'Alamat';

  @override
  String get placeTypeStreet => 'Jalan';

  @override
  String get placeTypePlace => 'Tempat';

  @override
  String get placeOptions => 'Pilihan tempat';

  @override
  String get modeParkRide => 'Kereta + pengangkutan awam';

  @override
  String get modeParkRideShort => 'Kereta+bas';

  @override
  String get scenarioParkRide => 'Kereta + pengangkutan awam';

  @override
  String get layerParking => 'Parkir berbayar';

  @override
  String get layerParkingHint =>
      'Zon dengan petak kosong, mengikut kiraan terakhir (zum 14+)';

  @override
  String get parkingZone => 'Zon parkir berbayar';

  @override
  String get parkingOwnCar => 'Kereta anda';

  @override
  String parkingLeaveCarAt(String place) {
    return 'Tinggalkan kereta di $place';
  }

  @override
  String parkingSpaces(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n petak',
      one: '1 petak',
    );
    return '$_temp0';
  }

  @override
  String parkingSpacesOf(int n, int total) {
    return '$n daripada $total petak';
  }

  @override
  String get parkingUnknownSpaces => 'Petak tanpa kiraan';

  @override
  String get parkingFull => 'Tiada petak kosong';

  @override
  String get parkingAllowedNow => 'Boleh parkir sekarang';

  @override
  String get parkingNotNow => 'Tidak boleh parkir sekarang';

  @override
  String parkingUntil(String time) {
    return 'sehingga $time';
  }

  @override
  String get parkingNoCount => 'Pengendali tidak menerbitkan kiraan';

  @override
  String parkingFeeFor(int hours) {
    return 'Parkir $hours j';
  }

  @override
  String parkingThenWalk(String distance, String duration) {
    return 'Kemudian berjalan $distance ($duration) ke hentian';
  }

  @override
  String get parkingContinueByTransit => 'Teruskan dengan pengangkutan awam';

  @override
  String get tripsTitle => 'Perjalanan berjadual';

  @override
  String get tripsSettingsHint =>
      'Peringatan pada malam sebelumnya dan pada waktu bertolak';

  @override
  String get tripsEmpty =>
      'Jadualkan perjalanan daripada keputusan atau daripada perjalanan Rumah ⇄ Tempat kerja anda dan kami beritahu bila perlu bertolak.';

  @override
  String get tripsRefresh => 'Kira semula';

  @override
  String get scheduleTrip => 'Jadualkan perjalanan';

  @override
  String get scheduleTripHint =>
      'Kami beritahu anda pada malam sebelumnya dengan waktu bertolak, 20 minit sebelumnya dengan data langsung, dan pada waktu bertolak.';

  @override
  String get scheduleArriveBy => 'Tiba pada';

  @override
  String get scheduleDepartAt => 'Bertolak pada';

  @override
  String get scheduleRepeat => 'Ulang';

  @override
  String get scheduleOnce => 'Sekali';

  @override
  String get scheduleSave => 'Jadualkan';

  @override
  String get scheduleSaved =>
      'Selesai. Kami beritahu anda pada malam sebelumnya dan pada waktu bertolak.';

  @override
  String get scheduleNotifDenied =>
      'Perjalanan disimpan, tetapi tanpa kebenaran pemberitahuan kami tidak dapat memberitahu anda.';

  @override
  String get tripWeekdays => 'Isn–Jum';

  @override
  String get tripDaily => 'Setiap hari';

  @override
  String get tripWeekend => 'Hujung minggu';

  @override
  String tripOnceOn(String date) {
    return '$date';
  }

  @override
  String tripArriveAt(String time) {
    return 'tiba $time';
  }

  @override
  String tripDepartAt(String time) {
    return 'bertolak $time';
  }

  @override
  String tripLeaveAround(String time) {
    return 'Bertolak ~$time';
  }

  @override
  String get tripPlanning => 'Mengira waktu bertolak…';

  @override
  String get tripPast => 'Sudah berlalu';

  @override
  String get tripDeleted => 'Perjalanan dipadam';

  @override
  String tripEveTitle(String to) {
    return 'Esok: $to';
  }

  @override
  String tripEveBody(String leave, String arrive, String routes) {
    return 'Bertolak pada $leave untuk tiba pada $arrive · $routes';
  }

  @override
  String tripRefineTitle(String leave) {
    return 'Bertolak pada $leave';
  }

  @override
  String tripRefineBody(String routes, String arrive) {
    return '$routes · tiba pada $arrive';
  }

  @override
  String get tripLeaveTitle => 'Masa untuk bertolak';

  @override
  String tripLeaveBody(String to, String routes, String arrive) {
    return 'Ke $to · $routes · tiba pada $arrive';
  }

  @override
  String get remindersPermissionOk => 'Peringatan dibenarkan';

  @override
  String get remindersPermissionUnknown => 'Menyemak kebenaran pemberitahuan…';

  @override
  String get remindersPermissionDenied =>
      'Pemberitahuan dinyahaktifkan untuk opentransit: peringatan dijadualkan, tetapi telefon tidak memaparkannya.';

  @override
  String get remindersOpenSettings => 'Benarkan pemberitahuan';

  @override
  String get remindersTest => 'Uji peringatan';

  @override
  String get remindersTestScheduled =>
      'Peringatan ujian akan tiba dalam 10 saat.';

  @override
  String get remindersTestTitle => 'Peringatan ujian';

  @override
  String get remindersTestBody => 'Beginilah rupa peringatan perjalanan anda.';

  @override
  String remindersArmed(String kinds) {
    return 'Peringatan ditetapkan: $kinds';
  }

  @override
  String get remindersEve => 'malam sebelumnya';

  @override
  String get remindersLeave => 'waktu bertolak';

  @override
  String get remindersNone =>
      'Tiada peringatan ditetapkan — semak kebenaran pemberitahuan';
}
