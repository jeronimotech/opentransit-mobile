// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'OpenTransit';

  @override
  String get chooseCity => 'اختر مدينتك';

  @override
  String get detectCity => 'اكتشاف مدينتي';

  @override
  String get detectingCity => 'جارٍ البحث عن مدينتك…';

  @override
  String cityDetected(String city) {
    return 'أنت في $city';
  }

  @override
  String get cityNotCovered => 'لا نغطي منطقتك بعد. اختر مدينة من القائمة.';

  @override
  String get cityDetectFailed => 'تعذّر استخدام موقعك. اختر مدينة من القائمة.';

  @override
  String get chooseCitySubtitle =>
      'خطّط رحلاتك بالنقل العمومي ببيانات مفتوحة وفي الوقت الفعلي.';

  @override
  String get searchPlaceholder => 'إلى أين تذهب؟';

  @override
  String get planTrip => 'خطّط رحلة';

  @override
  String get fromLabel => 'الانطلاق';

  @override
  String get toLabel => 'الوجهة';

  @override
  String get myLocation => 'موقعي';

  @override
  String get chooseOnMap => 'اختيار على الخريطة';

  @override
  String get departAt => 'المغادرة في';

  @override
  String get arriveBy => 'الوصول قبل';

  @override
  String get now => 'الآن';

  @override
  String get wheelchair => 'مناسب للكراسي المتحركة';

  @override
  String get modes => 'الوسائل';

  @override
  String get searchAction => 'بحث';

  @override
  String get results => 'النتائج';

  @override
  String get noItineraries =>
      'لم نجد مسارات لهذه الرحلة. جرّب وقتًا آخر أو وسّع مسافة المشي.';

  @override
  String transfersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تحويلات',
      one: 'تحويل واحد',
      zero: 'بدون تحويلات',
    );
    return '$_temp0';
  }

  @override
  String walkDistance(int meters) {
    return '$meters م مشيًا';
  }

  @override
  String get itinerary => 'المسار';

  @override
  String get departures => 'المغادرات القادمة';

  @override
  String get noDepartures => 'لا مغادرات مبرمجة خلال الساعة القادمة.';

  @override
  String get realtime => 'مباشر';

  @override
  String get scheduled => 'حسب الجدول';

  @override
  String get canceled => 'ملغاة';

  @override
  String delayedBy(int minutes) {
    return 'تأخير $minutes د';
  }

  @override
  String earlyBy(int minutes) {
    return 'مبكرة بـ $minutes د';
  }

  @override
  String get onTime => 'في الوقت';

  @override
  String get alerts => 'التنبيهات';

  @override
  String get noAlerts => 'لا تنبيهات نشطة.';

  @override
  String get favorites => 'المفضلة';

  @override
  String get noFavorites =>
      'احفظ المواقف والخطوط والأماكن لتكون في متناول يدك.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get city => 'المدينة';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get accessibility => 'إمكانية الوصول';

  @override
  String get wheelchairPref => 'تفضيل المسارات المناسبة للكراسي المتحركة';

  @override
  String get liveVehicles => 'المركبات مباشرة';

  @override
  String get nearbyStops => 'المواقف القريبة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get errorGeneric => 'حدث خطأ ما. تحقق من اتصالك وحاول مجددًا.';

  @override
  String get errorOffline => 'لا اتصال بالخادم.';

  @override
  String get routes => 'الخطوط';

  @override
  String get stops => 'المواقف';

  @override
  String get stop => 'موقف';

  @override
  String get route => 'خط';

  @override
  String get viewOnMap => 'عرض على الخريطة';

  @override
  String get share => 'مشاركة';

  @override
  String get addFavorite => 'حفظ في المفضلة';

  @override
  String get removeFavorite => 'إزالة من المفضلة';

  @override
  String minutesShort(int minutes) {
    return '$minutes د';
  }

  @override
  String durationHm(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String get walkSteps => 'إرشادات المشي';

  @override
  String intermediateStops(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مواقف وسيطة',
      two: 'موقفان وسيطان',
      one: 'موقف وسيط واحد',
      zero: 'بدون مواقف وسيطة',
    );
    return '$_temp0';
  }

  @override
  String updatedAgo(int seconds) {
    return 'حُدّث منذ $seconds ث';
  }

  @override
  String vehiclesCount(int count) {
    return '$count مركبة';
  }

  @override
  String get swap => 'تبديل الانطلاق والوجهة';

  @override
  String get places => 'الأماكن';

  @override
  String get tapToSetPlace => 'اضغط على الخريطة لاختيار النقطة';

  @override
  String get longPressHint => 'اضغط مطولًا على الخريطة لتثبيت نقطة';

  @override
  String get setAsOrigin => 'استخدام كنقطة انطلاق';

  @override
  String get setAsDestination => 'استخدام كوجهة';

  @override
  String get home => 'الرئيسية';

  @override
  String get about => 'حول';

  @override
  String get version => 'الإصدار';

  @override
  String get dataSource => 'مصدر البيانات';

  @override
  String get mockMode => 'الوضع التجريبي (بيانات نموذجية)';

  @override
  String get direction => 'الاتجاه';

  @override
  String stopsCount(int count) {
    return '$count مواقف';
  }

  @override
  String towards(String headsign) {
    return 'باتجاه $headsign';
  }

  @override
  String walkTo(String place) {
    return 'امشِ حتى $place';
  }

  @override
  String rideTo(String place) {
    return 'انزل في $place';
  }

  @override
  String boardAt(String place) {
    return 'اركب في $place';
  }

  @override
  String arriveAt(String place) {
    return 'تصل إلى $place';
  }

  @override
  String get moreOptions => 'خيارات أكثر';

  @override
  String get walkingDistance => 'أقصى مسافة مشي';

  @override
  String get changeCity => 'تغيير المدينة';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String inMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String get arrivingNow => 'الآن';

  @override
  String get seeAlerts => 'عرض التنبيهات';

  @override
  String get affectedRoutes => 'الخطوط المتأثرة';

  @override
  String get componentTrunk => 'رئيسي';

  @override
  String get componentFeeder => 'مغذٍّ';

  @override
  String get componentDual => 'مزدوج';

  @override
  String get componentZonal => 'محلي';

  @override
  String get componentCable => 'تلفريك';

  @override
  String get componentRail => 'قطار';

  @override
  String get componentTram => 'طرامواي';

  @override
  String get componentBus => 'حافلة';

  @override
  String get componentOther => 'آخر';

  @override
  String get modeWalk => 'مشيًا';

  @override
  String get modeBus => 'حافلة';

  @override
  String get modeRail => 'قطار';

  @override
  String get modeSubway => 'مترو';

  @override
  String get modeTram => 'طرامواي';

  @override
  String get modeCableCar => 'تلفريك';

  @override
  String get modeBicycle => 'دراجة';

  @override
  String get modeCar => 'سيارة';

  @override
  String get modeFerry => 'عبّارة';

  @override
  String get modeTransit => 'النقل العمومي';

  @override
  String get locationDenied => 'لا إذن للموقع. فعّله في إعدادات النظام.';

  @override
  String get reverseTrip => 'عكس الرحلة';

  @override
  String get openInPlanner => 'فتح في المخطِّط';

  @override
  String get goHere => 'الذهاب إلى هنا';

  @override
  String get leaveFrom => 'الانطلاق من هنا';

  @override
  String get fromHere => 'من هنا';

  @override
  String get accessible => 'مناسب للكراسي المتحركة';

  @override
  String get hubTitle => 'ماذا تريد أن تعرف؟';

  @override
  String get tilePlan => 'خطّط رحلة';

  @override
  String get tileLocate => 'أين حافلتي؟';

  @override
  String get tileNearby => 'مواقف قريبة';

  @override
  String get tileRoutes => 'ابحث عن خط';

  @override
  String get tileLive => 'الحافلات مباشرة';

  @override
  String get tileAlerts => 'التنبيهات';

  @override
  String get tileFavorites => 'المفضلة';

  @override
  String get nearbyCardTitle => 'محطات ومواقف قريبة';

  @override
  String get services => 'الخدمات';

  @override
  String get messagesOfInterest => 'رسائل تهمّك';

  @override
  String get dismiss => 'إخفاء';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get locateTitle => 'أين حافلتي؟';

  @override
  String get locateStep1 => 'اختر محطة أو موقفًا';

  @override
  String get locateStep2 => 'اختر الخط';

  @override
  String get locateNext => 'الحافلات القادمة';

  @override
  String get sourceLive => 'مباشر';

  @override
  String get sourceScheduled => 'حسب الجدول';

  @override
  String get sourceEstimated => 'تقديري';

  @override
  String stopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مواقف',
      one: 'موقف واحد',
    );
    return '$_temp0';
  }

  @override
  String get noBuses => 'لا حافلات قادمة لهذا الخط.';

  @override
  String get searchStopHint => 'ابحث عن محطة أو موقف';

  @override
  String get changeStop => 'تغيير الموقف';

  @override
  String get board => 'الحافلات القادمة';

  @override
  String nextIn(int minutes) {
    return 'التالية بعد $minutes د';
  }

  @override
  String thenAt(String list) {
    return 'ثم $list';
  }

  @override
  String get noBoard => 'لا حافلات خلال الساعة القادمة.';

  @override
  String get freshLive => 'مباشر';

  @override
  String get freshScheduled => 'حسب الجدول';

  @override
  String freshStale(int seconds) {
    return 'لا بيانات مباشرة منذ $seconds ث';
  }

  @override
  String get freshNoRealtime => 'لا بيانات مباشرة';

  @override
  String get outOfHours => 'خارج أوقات الخدمة';

  @override
  String nextAt(String time) {
    return 'التالية $time';
  }

  @override
  String get noServiceToday => 'لا خدمة اليوم';

  @override
  String get serviceHours => 'أوقات الخدمة';

  @override
  String get estimatedFare => 'الأجرة التقديرية';

  @override
  String get fareNotPublished => 'الأجرة غير منشورة';

  @override
  String get fareBase => 'التذكرة';

  @override
  String get fareTransfer => 'التحويل';

  @override
  String get fareEstimatedNote => 'تقدير بالأجرة المضبوطة للمدينة؛ قد تختلف.';

  @override
  String get sortFastest => 'الأسرع';

  @override
  String get sortFewerTransfers => 'أقل تحويلات';

  @override
  String get sortLessWalking => 'أقل مشيًا';

  @override
  String get sortCheapest => 'الأرخص';

  @override
  String get sortEarliest => 'أقرب مغادرة';

  @override
  String get sortBy => 'ترتيب';

  @override
  String get favHome => 'المنزل';

  @override
  String get favWork => 'العمل';

  @override
  String get favCustom => 'آخر';

  @override
  String get saveAs => 'حفظ باسم';

  @override
  String get recentTrips => 'الرحلات الأخيرة';

  @override
  String get clearRecent => 'مسح';

  @override
  String get setHome => 'تحديد المنزل';

  @override
  String get setWork => 'تحديد العمل';

  @override
  String get chooseIcon => 'اختر أيقونة';

  @override
  String get saveFavorite => 'حفظ المفضلة';

  @override
  String get favoriteName => 'الاسم';

  @override
  String get updateRequired => 'حدّث التطبيق';

  @override
  String get updateRequiredBody =>
      'هذا الإصدار لم يعد مدعومًا. حدّث لمواصلة استخدام OpenTransit.';

  @override
  String get updateAction => 'تحديث';

  @override
  String get updateOpenFailed =>
      'تعذّر فتح المتجر. ابحث عنا باسم «opentransit» للتحديث.';

  @override
  String get maintenanceTitle => 'قيد الصيانة';

  @override
  String get maintenanceBody => 'نجري تحسينات. حاول مجددًا بعد بضع دقائق.';

  @override
  String get checkAgain => 'إعادة المحاولة';

  @override
  String get shareCopied => 'تم نسخ الرابط';

  @override
  String get shareTrip => 'مشاركة الرحلة';

  @override
  String get copyLink => 'نسخ الرابط';

  @override
  String get openInWeb => 'فتح في الموقع';

  @override
  String get startTrip => 'بدء الرحلة';

  @override
  String get stopTrip => 'إنهاء';

  @override
  String get currentLeg => 'المقطع الحالي';

  @override
  String get nextStopIsYours => 'الموقف التالي هو موقفك';

  @override
  String getOffAt(String stop) {
    return 'انزل في $stop';
  }

  @override
  String get followAlongHint => 'ننبهك عندما تقترب من موقف نزولك.';

  @override
  String progressLabel(int done, int total) {
    return 'المقطع $done من $total';
  }

  @override
  String get arrived => 'لقد وصلت!';

  @override
  String distanceToStop(String distance) {
    return '$distance حتى موقفك';
  }

  @override
  String get followAlongLocationNeeded => 'نحتاج إلى موقعك لمتابعة الرحلة.';

  @override
  String get poiLayer => 'الخدمات في المحطات';

  @override
  String get poiBikeParking => 'موقف دراجات';

  @override
  String get poiToilets => 'مراحيض';

  @override
  String get poiAtm => 'صراف آلي';

  @override
  String get poiHealth => 'نقطة صحية';

  @override
  String get poiLibrary => 'مكتبة';

  @override
  String get poiOther => 'خدمة';

  @override
  String get accessibilityUnverified => 'بيانات التغذية غير متحقق منها';

  @override
  String get accessibilityNotAccessible => 'غير مناسب';

  @override
  String get accessibilityUnknown => 'لا معلومات عن إمكانية الوصول';

  @override
  String accessibilitySource(String source) {
    return 'المصدر: $source';
  }

  @override
  String get accessibilityVerified => 'تم التحقق';

  @override
  String get nearYou => 'بالقرب منك';

  @override
  String get bikeToStation => 'الوصول إلى المحطة بالدراجة';

  @override
  String get reportProblem => 'الإبلاغ عن مشكلة';

  @override
  String get pqrs => 'الشكاوى';

  @override
  String get openExternal => 'فتح الرابط';

  @override
  String get rechargeCard => 'شحن البطاقة';

  @override
  String get routesSearchHint => 'ابحث عن خط (مثلًا B10)';

  @override
  String get station => 'محطة';

  @override
  String get etaLegend => '≤5 · ≤10 · ≤15 د';

  @override
  String get live => 'مباشر';

  @override
  String get allRoutes => 'جميع الخطوط';

  @override
  String get noRoutes => 'لم نجد خطوطًا.';

  @override
  String minutesOnly(int minutes) {
    return '$minutes د';
  }

  @override
  String get now2 => 'الآن';

  @override
  String vehicleAgo(int seconds) {
    return 'منذ $seconds ث';
  }

  @override
  String get goToStop => 'الذهاب إلى الموقف';

  @override
  String get showOnMap => 'عرض على الخريطة';

  @override
  String get selectRoute => 'اختر خطًا';

  @override
  String get layers => 'الطبقات';

  @override
  String get layerLive => 'الحافلات مباشرة';

  @override
  String get layerLiveHint => 'تظهر عند تكبير الخريطة (تكبير 14+)';

  @override
  String get layerPois => 'الخدمات';

  @override
  String get layerNetwork => 'شبكة الخطوط';

  @override
  String get nearYouTitle => 'بالقرب منك';

  @override
  String get zoomInForBuses => 'كبّر الخريطة لرؤية الحافلات';

  @override
  String get actionPlan => 'خطّط رحلة';

  @override
  String get actionLocate => 'أين حافلتي؟';

  @override
  String get actionRoutes => 'ابحث عن خط';

  @override
  String get timeNow => 'الآن';

  @override
  String get timeSheetTitle => 'متى تسافر؟';

  @override
  String get modeBike => 'دراجة';

  @override
  String get modeWalkShort => 'مشيًا';

  @override
  String routesCount(int count) {
    return 'الخطوط · $count';
  }

  @override
  String get viewOnMapAction => 'عرض على الخريطة';

  @override
  String get noNearbyStops => 'لا مواقف قرب هذه النقطة';

  @override
  String get done => 'تم';

  @override
  String get layerNetworkHint => 'مسارات الشبكة الرئيسية';

  @override
  String get layerNetworkZonalHint => 'مئات المسارات المتداخلة';

  @override
  String thenTimes(String times) {
    return 'ثم بعد $times د';
  }

  @override
  String get modeBikeShare => 'دراجة مشتركة';

  @override
  String rentalPickup(String station) {
    return 'خذ دراجة من $station';
  }

  @override
  String rentalDropoff(String station) {
    return 'اترك الدراجة في $station';
  }

  @override
  String rentalRide(String duration, String distance) {
    return 'بدّل $duration · $distance';
  }

  @override
  String bikesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دراجات متاحة',
      two: 'دراجتان متاحتان',
      one: 'دراجة واحدة متاحة',
      zero: 'لا دراجات متاحة',
    );
    return '$_temp0';
  }

  @override
  String docksAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرابط حرة',
      two: 'مربطان حران',
      one: 'مربط واحد حر',
      zero: 'لا مرابط حرة',
    );
    return '$_temp0';
  }

  @override
  String bikesShort(int count) {
    return '$count دراجات';
  }

  @override
  String ebikesShort(int count) {
    return '$count كهربائية';
  }

  @override
  String docksShort(int count) {
    return '$count مرابط';
  }

  @override
  String openApp(String name) {
    return 'فتح $name';
  }

  @override
  String get layerBikeShare => 'الدراجات المشتركة';

  @override
  String get layerBikeShareHint => 'المحطات والدراجات المتاحة (تكبير 14+)';

  @override
  String get rentalStation => 'محطة دراجات';

  @override
  String get howToGetThere => 'كيفية الوصول';

  @override
  String noRentalData(String name) {
    return 'لا بيانات من $name الآن';
  }

  @override
  String get rentalNotRenting => 'لا تعير دراجات حاليًا';

  @override
  String get rentalNotReturning => 'لا تستقبل دراجات حاليًا';

  @override
  String rentalPriceLine(String amount, String label) {
    return '≈ $amount · $label';
  }

  @override
  String get rentalDockHint => 'عند الوصول، اترك الدراجة مثبّتة في المحطة.';

  @override
  String sharedBikeOf(String name) {
    return 'دراجة مشتركة · $name';
  }

  @override
  String get electricBike => 'كهربائية';

  @override
  String get rentalUnavailableHint => 'لا بيانات عن المحطات في هذه المنطقة.';

  @override
  String get modeScooter => 'سكوتر';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'حُدّث منذ $minutes د';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'حُدّث منذ $hours س';
  }

  @override
  String get modeOnDemand => 'تاكسي / تطبيق';

  @override
  String get onDemandTaxi => 'تاكسي';

  @override
  String get onDemandRidehail => 'تطبيق نقل';

  @override
  String get priceInApp => 'السعر في التطبيق';

  @override
  String get requestRide => 'اطلب';

  @override
  String get requestVehicle => 'اطلب مركبتك';

  @override
  String requestVehicleTo(String place) {
    return 'اطلب مركبتك نحو $place';
  }

  @override
  String onDemandRideLine(String duration, String distance) {
    return '$duration · $distance بالسيارة';
  }

  @override
  String get chooseProvider => 'اختر كيف تطلبها';

  @override
  String get recommended => 'موصى به';

  @override
  String waitMinutes(int minutes) {
    return '$minutes د انتظار';
  }

  @override
  String tariffSource(String source) {
    return 'تقدير حسب $source · العدّاد هو المرجع';
  }

  @override
  String get onDemandToHere => 'الوصول بتاكسي / تطبيق';

  @override
  String get onDemandNoProviders =>
      'لا تاكسي ولا تطبيقات نقل مضبوطة في هذه المدينة.';

  @override
  String get onDemandOpenFailed => 'تعذّر فتح تطبيق المزوّد.';

  @override
  String get taxiToBus => 'تاكسي ← حافلة';

  @override
  String get onDemandOffline => 'تعذّر الحصول على تقدير الرحلة.';

  @override
  String requestProviderPriced(String name, String price) {
    return 'اطلب $name · $price';
  }

  @override
  String requestWithProvider(String name) {
    return 'اطلب عبر $name';
  }

  @override
  String get orRequestWith => 'أو اطلب عبر:';

  @override
  String get seePrices => 'عرض الأسعار';

  @override
  String get hidePrices => 'إخفاء الأسعار';

  @override
  String onDemandDestination(String place) {
    return 'نحو $place';
  }

  @override
  String get viewFullRoute => 'عرض الخط كاملًا';

  @override
  String get locateNoLive => 'لا حافلات مباشرة على هذا الخط الآن';

  @override
  String locateNoneComing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حافلات في الخدمة',
      two: 'حافلتان في الخدمة',
      one: 'حافلة واحدة في الخدمة',
    );
    return '$_temp0 · لا تتجه أي منها إلى هذا الموقف بعد';
  }

  @override
  String locateComing(int count, int coming) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حافلات في الخدمة',
      two: 'حافلتان في الخدمة',
      one: 'حافلة واحدة في الخدمة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      coming,
      locale: localeName,
      other: '$coming قادمة',
      two: 'اثنتان قادمتان',
      one: 'واحدة قادمة',
    );
    return '$_temp0 · $_temp1 نحو هذا الموقف';
  }

  @override
  String get modeSharedShort => 'مشتركة';

  @override
  String get modeOnDemandShort => 'تاكسي/تطبيق';

  @override
  String get stateOn => 'مفعّل';

  @override
  String get stateOff => 'معطّل';

  @override
  String leaveIn(int minutes) {
    return 'انطلق بعد $minutes د';
  }

  @override
  String get leaveNow => 'انطلق الآن';

  @override
  String get departed => 'غادرت بالفعل';

  @override
  String get refreshResults => 'تحديث';

  @override
  String get scenarioFastest => 'الأسرع';

  @override
  String get scenarioLessWalking => 'أقل مشيًا';

  @override
  String get scenarioFewerTransfers => 'أقل تحويلات';

  @override
  String get scenarioCheapest => 'الأرخص';

  @override
  String get scenarioBike => 'بالدراجة';

  @override
  String get scenarioOnDemand => 'تاكسي / تطبيق';

  @override
  String get sortByScenario => 'حسب السيناريو';

  @override
  String get orderMenu => 'ترتيب';

  @override
  String moreOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خيارات إضافية',
      two: 'خياران إضافيان',
      one: 'خيار إضافي واحد',
    );
    return '$_temp0';
  }

  @override
  String get nextDeparturesHere => 'المغادرات القادمة هنا';

  @override
  String get retimed => 'معاد توقيته';

  @override
  String get retimedHint => 'الأوقات معدَّلة حسب المغادرة المختارة';

  @override
  String andThenTimes(String times) {
    return 'وبعد $times د';
  }

  @override
  String get noStopsNearbyWalk => 'لا مواقف على بعد 30 د مشيًا';

  @override
  String get noBoardContext => 'لا مغادرات قريبة في هذا الموقف';

  @override
  String get noLiveScheduledBelow =>
      'لا حافلات مباشرة على هذا الخط الآن · الجدول الزمني أدناه';

  @override
  String get offlineBar => 'بدون اتصال · تُعرض البيانات المحفوظة';

  @override
  String get backOnlineBar => 'عاد الاتصال';

  @override
  String staleBar(int seconds) {
    return 'بيانات مباشرة متأخرة · منذ $seconds ث';
  }

  @override
  String get privacyTitle => 'الخصوصية';

  @override
  String get analyticsToggle => 'مشاركة إحصاءات استخدام مجهولة الهوية';

  @override
  String get analyticsExplain =>
      'ساعد على تحسين النقل في مدينتك: بيانات مجهولة ومجمّعة فقط، وليس موقعك الدقيق أبدًا.';

  @override
  String get analyticsClear => 'حذف إحصاءاتي';

  @override
  String get analyticsCleared => 'حُذفت الإحصاءات وجُدّد المعرّف';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get agencyPrivacyPolicy => 'سياسة خصوصية الهيئة';

  @override
  String get commuteToWork => 'إلى العمل';

  @override
  String get commuteToHome => 'إلى المنزل';

  @override
  String get commuteInvert => 'عكس';

  @override
  String get commuteSeeRoute => 'عرض المسار';

  @override
  String get commuteNoPlan => 'لا خيارات الآن';

  @override
  String get commuteDetour => 'مسار به تحويل · إعادة التخطيط';

  @override
  String get commuteSetup => 'احفظ المنزل والعمل لرؤية مشوارك هنا';

  @override
  String get departuresSheetTitle => 'متى تنطلق';

  @override
  String get departuresButton => 'المغادرات';

  @override
  String get forecastRecommended => 'أفضل خيار';

  @override
  String forecastGap(String time) {
    return 'بعدها لا خدمة حتى $time';
  }

  @override
  String get forecastEmpty => 'لا مغادرات أخرى في هذه الفترة';

  @override
  String forecastArrive(String time) {
    return 'تصل $time';
  }

  @override
  String get forecastPickThis => 'التخطيط لهذا الوقت';

  @override
  String get routeAlertsTitle => 'إشعارات هذا الخط';

  @override
  String get routeAlertsAlways => 'دائمًا';

  @override
  String get routeAlertsWeekdays => 'أيام العمل فقط';

  @override
  String get routeAlertsWorkHours => 'ساعات العمل فقط';

  @override
  String get routeAlertsNever => 'أبدًا';

  @override
  String get routeAlertsOn => 'الإشعارات مفعّلة';

  @override
  String get routeAlertsOff => 'الإشعارات معطّلة';

  @override
  String routeAlertNotificationTitle(String route) {
    return '$route: مستجد في خطك';
  }

  @override
  String get quickGo => 'GO سريع';

  @override
  String busesOnRoute(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حافلات في الخدمة',
      two: 'حافلتان في الخدمة',
      one: 'حافلة واحدة في الخدمة',
      zero: 'لا حافلات مباشرة',
    );
    return '$_temp0';
  }

  @override
  String get goReceiptTitle => 'انتهت الرحلة';

  @override
  String get goReceiptPlanned => 'المخطَّط';

  @override
  String get goReceiptActual => 'الفعلي';

  @override
  String get goReceiptDistance => 'المسافة';

  @override
  String get goReceiptModes => 'الوسائل';

  @override
  String get goReceiptCost => 'التكلفة التقديرية';

  @override
  String get goReceiptCo2 => 'CO₂ موفَّر مقارنة بالسيارة';

  @override
  String get goReceiptClose => 'تم';

  @override
  String get goOffRoute => 'يبدو أنك خرجت عن المسار';

  @override
  String get goReplan => 'إعادة التخطيط';

  @override
  String get goRecenter => 'العودة إلى موقعي';

  @override
  String get goReplanFailed => 'تعذّرت إعادة الحساب. ما زلت على المسار السابق.';

  @override
  String get goDismiss => 'المتابعة كما هو';

  @override
  String get goNotificationTitle => 'رحلة جارية';

  @override
  String goNotificationBody(String stop, int minutes, String time) {
    return 'انزل في $stop · $minutes د · تصل $time';
  }

  @override
  String get goLocationWhy => 'نستخدم موقعك فقط طوال الرحلة، لننبهك متى تنزل.';

  @override
  String get shareTripCreating => 'جارٍ إنشاء الرابط…';

  @override
  String get shareTripCopied => 'تم نسخ الرابط';

  @override
  String get shareTripStop => 'إيقاف المشاركة';

  @override
  String get shareTripStopped => 'الرابط لم يعد نشطًا';

  @override
  String get shareTripFailed => 'تعذّر إنشاء الرابط';

  @override
  String get shareTripActive => 'مشاركة مباشرة';

  @override
  String get ok => 'فهمت';

  @override
  String get nearMeTitle => 'بالقرب مني';

  @override
  String get nearMeEntry => 'حافلات قريبة';

  @override
  String get nearMeLoading => 'جارٍ البحث عن حافلات…';

  @override
  String nearMeCount(int count, String radius) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حافلات في نطاق $radius',
      two: 'حافلتان في نطاق $radius',
      one: 'حافلة واحدة في نطاق $radius',
      zero: 'لا حافلات في نطاق $radius',
    );
    return '$_temp0';
  }

  @override
  String nearMeEmpty(String radius) {
    return 'لا حافلات في نطاق $radius';
  }

  @override
  String nearMeWiden(String radius) {
    return 'توسيع إلى $radius';
  }

  @override
  String nearMeAt(String distance) {
    return 'على بعد $distance';
  }

  @override
  String get nearMeApproaching => 'تقترب';

  @override
  String get nearMeLeaving => 'تبتعد';

  @override
  String get nearMeNeedsLocation =>
      'نحتاج إلى موقعك لنعرض لك الحافلات من حولك.';

  @override
  String get backToMyLocation => 'العودة إلى موقعي';

  @override
  String get assistantTitle => 'اسألني';

  @override
  String get assistantIntro =>
      'أجيب ببيانات المدينة: أخطط الرحلات، وأطّلع على المغادرات القادمة، وأراجع التحويلات. وإذا لم أستطع معرفة الجواب، أخبرك بذلك.';

  @override
  String get assistantPlaceholder => 'اسأل عن خط أو حافلة';

  @override
  String get assistantSend => 'إرسال';

  @override
  String get assistantStop => 'إيقاف';

  @override
  String get assistantClose => 'إغلاق';

  @override
  String get assistantThinking => 'أفكر…';

  @override
  String assistantNotice(String provider) {
    return 'تُرسل أسئلتك إلى $provider لصياغة الإجابة. لا نرسل موقعك الدقيق ولا نحفظ المحادثة.';
  }

  @override
  String get assistantSuggestion1 => 'كيف أصل إلى وسط المدينة؟';

  @override
  String get assistantSuggestion2 => 'متى تمر الحافلة القادمة؟';

  @override
  String get assistantSuggestion3 => 'هل توجد تحويلات اليوم؟';

  @override
  String get assistantToolPlanTrip => 'جارٍ البحث عن مسارات…';

  @override
  String get assistantToolFindPlace => 'جارٍ البحث عن المكان…';

  @override
  String get assistantToolNextDepartures =>
      'جارٍ الاستعلام عن المغادرات القادمة…';

  @override
  String get assistantToolLocateBus => 'جارٍ تحديد موقع الحافلة…';

  @override
  String get assistantToolServiceAlerts => 'جارٍ مراجعة التحويلات…';

  @override
  String get assistantToolFareEstimate => 'جارٍ حساب الأجرة…';

  @override
  String get assistantToolNearbyStops => 'جارٍ البحث عن مواقف قريبة…';

  @override
  String get assistantToolBikeStations => 'جارٍ البحث عن دراجات…';

  @override
  String get assistantToolVehiclesNear => 'جارٍ البحث عن حافلات قريبة…';

  @override
  String get assistantToolRouteInfo => 'جارٍ الاستعلام عن الخط…';

  @override
  String get assistantErrBudget =>
      'بلغ المساعد ميزانيته لليوم. عد غدًا أو استخدم المخطِّط.';

  @override
  String get assistantErrDisabled => 'المساعد غير متاح في هذه المدينة.';

  @override
  String get assistantErrRate =>
      'أنت تسأل بسرعة كبيرة. انتظر قليلًا ثم أعد السؤال.';

  @override
  String get assistantErrUpstream => 'لم أستطع الإجابة الآن. حاول مجددًا.';

  @override
  String get assistantNewConversation => 'محادثة جديدة';

  @override
  String get assistantNewConfirm =>
      'بدء محادثة جديدة؟ سيُمسح ما سألته حتى الآن.';

  @override
  String get assistantNewConfirmCta => 'البدء من جديد';

  @override
  String get cancel => 'إلغاء';

  @override
  String get pickOnMapHint => 'حرّك الخريطة لاختيار النقطة';

  @override
  String get pickOnMapSearching => 'جارٍ البحث عن العنوان…';

  @override
  String get pickOnMapConfirmOrigin => 'تأكيد نقطة الانطلاق';

  @override
  String get pickOnMapConfirmDestination => 'تأكيد الوجهة';

  @override
  String get dragPinsHint => 'اسحب العلامات لتحريك نقطة الانطلاق أو الوجهة';

  @override
  String get replanning => 'جارٍ إعادة حساب الرحلة…';

  @override
  String get replanFailed => 'تعذّرت إعادة حساب الرحلة';

  @override
  String get placeTypeStation => 'محطة';

  @override
  String get placeTypeStop => 'موقف';

  @override
  String get placeTypeAddress => 'عنوان';

  @override
  String get placeTypeStreet => 'شارع';

  @override
  String get placeTypePlace => 'مكان';

  @override
  String get placeOptions => 'خيارات المكان';

  @override
  String get modeParkRide => 'سيارة + نقل عمومي';

  @override
  String get modeParkRideShort => 'سيارة+حافلة';

  @override
  String get scenarioParkRide => 'سيارة + نقل عمومي';

  @override
  String get layerParking => 'ركن مدفوع';

  @override
  String get layerParkingHint =>
      'مناطق بها أماكن شاغرة، حسب آخر إحصاء (تكبير 14+)';

  @override
  String get parkingZone => 'منطقة ركن مدفوعة';

  @override
  String get parkingOwnCar => 'سيارتك';

  @override
  String parkingLeaveCarAt(String place) {
    return 'اترك السيارة في $place';
  }

  @override
  String parkingSpaces(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n أماكن',
      one: 'مكان واحد',
    );
    return '$_temp0';
  }

  @override
  String parkingSpacesOf(int n, int total) {
    return '$n من $total مكانًا';
  }

  @override
  String get parkingUnknownSpaces => 'أماكن بدون إحصاء';

  @override
  String get parkingFull => 'لا أماكن شاغرة';

  @override
  String get parkingAllowedNow => 'يمكنك الركن الآن';

  @override
  String get parkingNotNow => 'لا يمكن الركن الآن';

  @override
  String parkingUntil(String time) {
    return 'حتى $time';
  }

  @override
  String get parkingNoCount => 'المشغّل لا ينشر الإحصاء';

  @override
  String parkingFeeFor(int hours) {
    return 'ركن $hours س';
  }

  @override
  String parkingThenWalk(String distance, String duration) {
    return 'ثم $distance مشيًا ($duration) حتى الموقف';
  }

  @override
  String get parkingContinueByTransit => 'المتابعة بالنقل العمومي';

  @override
  String get tripsTitle => 'الرحلات المجدولة';

  @override
  String get tripsSettingsHint => 'تنبيهات في الليلة السابقة وعند وقت الانطلاق';

  @override
  String get tripsEmpty =>
      'جدوِل رحلة من نتيجة أو من مشوارك المنزل ⇄ العمل وننبهك متى تنطلق.';

  @override
  String get tripsRefresh => 'إعادة الحساب';

  @override
  String get scheduleTrip => 'جدولة رحلة';

  @override
  String get scheduleTripHint =>
      'ننبهك في الليلة السابقة بوقت الانطلاق، وقبل 20 دقيقة ببيانات مباشرة، وعند وقت الانطلاق.';

  @override
  String get scheduleArriveBy => 'الوصول في';

  @override
  String get scheduleDepartAt => 'المغادرة في';

  @override
  String get scheduleRepeat => 'تكرار';

  @override
  String get scheduleOnce => 'مرة واحدة';

  @override
  String get scheduleSave => 'جدولة';

  @override
  String get scheduleSaved => 'تم. ننبهك في الليلة السابقة وعند وقت الانطلاق.';

  @override
  String get scheduleNotifDenied =>
      'حُفظت الرحلة، لكن بدون إذن الإشعارات لا نستطيع تنبيهك.';

  @override
  String get tripWeekdays => 'الاثنين–الجمعة';

  @override
  String get tripDaily => 'كل يوم';

  @override
  String get tripWeekend => 'نهاية الأسبوع';

  @override
  String tripOnceOn(String date) {
    return '$date';
  }

  @override
  String tripArriveAt(String time) {
    return 'الوصول $time';
  }

  @override
  String tripDepartAt(String time) {
    return 'المغادرة $time';
  }

  @override
  String tripLeaveAround(String time) {
    return 'انطلق ~$time';
  }

  @override
  String get tripPlanning => 'جارٍ حساب وقت الانطلاق…';

  @override
  String get tripPast => 'انقضت';

  @override
  String get tripDeleted => 'حُذفت الرحلة';

  @override
  String tripEveTitle(String to) {
    return 'غدًا: $to';
  }

  @override
  String tripEveBody(String leave, String arrive, String routes) {
    return 'انطلق في $leave لتصل في $arrive · $routes';
  }

  @override
  String tripRefineTitle(String leave) {
    return 'انطلق في $leave';
  }

  @override
  String tripRefineBody(String routes, String arrive) {
    return '$routes · تصل في $arrive';
  }

  @override
  String get tripLeaveTitle => 'حان وقت الانطلاق';

  @override
  String tripLeaveBody(String to, String routes, String arrive) {
    return 'نحو $to · $routes · تصل في $arrive';
  }

  @override
  String get remindersPermissionOk => 'التنبيهات مسموح بها';

  @override
  String get remindersPermissionUnknown => 'جارٍ التحقق من إذن الإشعارات…';

  @override
  String get remindersPermissionDenied =>
      'الإشعارات معطّلة لـ opentransit: تُجدوَل التنبيهات لكن الهاتف لا يعرضها.';

  @override
  String get remindersOpenSettings => 'السماح بالإشعارات';

  @override
  String get remindersTest => 'اختبار تنبيه';

  @override
  String get remindersTestScheduled => 'سيصلك تنبيه تجريبي خلال 10 ثوانٍ.';

  @override
  String get remindersTestTitle => 'تنبيه تجريبي';

  @override
  String get remindersTestBody => 'هكذا ستبدو تذكيرات رحلاتك.';

  @override
  String remindersArmed(String kinds) {
    return 'التنبيهات المفعّلة: $kinds';
  }

  @override
  String get remindersEve => 'الليلة السابقة';

  @override
  String get remindersLeave => 'وقت الانطلاق';

  @override
  String get remindersNone => 'لا تنبيهات مفعّلة — راجع إذن الإشعارات';
}
