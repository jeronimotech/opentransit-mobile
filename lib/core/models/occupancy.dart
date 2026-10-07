/// How full a vehicle is, where the agency says so (GTFS-RT `occupancy_status`).
///
/// The API passes the enum through as its protobuf name, so parsing belongs here rather than in
/// whichever screen happens to draw it — `vehicle_detail_screen` had its own `switch` that fell
/// through to printing the raw name, which is how Lisboa would have shown a rider the literal text
/// `NO_DATA_AVAILABLE`.
///
/// Measured against production on 2026-10-07: Boston (252 many / 14 few / 4 full of 402), Toronto
/// (1385 empty / 101 few / 3 full of 1516) and Roma (37 many / 1 standing of 75) publish it; Bogotá,
/// Brisbane and Kuala Lumpur publish nothing; Lisboa publishes `NO_DATA_AVAILABLE` for every
/// vehicle, which is the feed saying "I don't know" and must read as no badge at all.
enum Occupancy {
  /// `NO_DATA_AVAILABLE`, `NOT_BOARDABLE`, an absent field, or a value added to the spec after us.
  /// Everything else in this enum is a claim; this is the absence of one, and it draws nothing.
  unknown,
  empty,
  manySeats,
  fewSeats,
  standing,
  crushed,
  full,

  /// The vehicle will not take more passengers. Not a crowding level — a refusal.
  notAccepting;

  static Occupancy parse(String? raw) => switch (raw) {
        'EMPTY' => Occupancy.empty,
        'MANY_SEATS_AVAILABLE' => Occupancy.manySeats,
        'FEW_SEATS_AVAILABLE' => Occupancy.fewSeats,
        'STANDING_ROOM_ONLY' => Occupancy.standing,
        'CRUSHED_STANDING_ROOM_ONLY' => Occupancy.crushed,
        'FULL' => Occupancy.full,
        'NOT_ACCEPTING_PASSENGERS' => Occupancy.notAccepting,
        // NO_DATA_AVAILABLE and NOT_BOARDABLE both mean "do not draw a crowding level", the first
        // because the agency does not know and the second because nobody is boarding this one.
        _ => Occupancy.unknown,
      };

  bool get isKnown => this != Occupancy.unknown;

  /// Filled dots out of three, for the glance. 0 for [unknown], which draws nothing anyway.
  int get dots => switch (this) {
        Occupancy.unknown => 0,
        Occupancy.empty || Occupancy.manySeats => 1,
        Occupancy.fewSeats => 2,
        Occupancy.standing || Occupancy.crushed || Occupancy.full || Occupancy.notAccepting => 3,
      };

  /// True once there is no seat left, which is where the colour stops being reassuring.
  bool get isCrowded => dots >= 3;

  /// True when boarding is in doubt, not merely uncomfortable.
  bool get isSevere => this == Occupancy.full || this == Occupancy.notAccepting;
}
