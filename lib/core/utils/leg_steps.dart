import '../../l10n/generated/app_localizations.dart';
import '../models/plan.dart';

/// The one-line instruction for a leg.
///
/// Guided-trip cards show two of these at once — the action you are doing and
/// the one after it — so both come from here: a rider who reads "bájate en X"
/// above and "camina hasta Y" below should not have to reconcile two different
/// ways of saying the same kind of thing.
///
/// [boarded] only matters for a transit leg: before boarding the instruction is
/// where to get on, after it where to get off. A leg you have not reached yet is
/// never boarded, so the "next step" line always asks for the default.
String legInstruction(AppLocalizations l10n, Leg leg, {bool boarded = false}) {
  if (leg.transit) return boarded ? l10n.getOffAt(leg.to.name) : l10n.boardAt(leg.from.name);
  if (leg.parkRide) return l10n.parkingLeaveCarAt(leg.to.name);
  if (leg.isRental) return l10n.rentalDropoff(leg.rental?.dropoff?.name ?? leg.to.name);
  if (leg.isOnDemand) return l10n.requestVehicleTo(leg.to.name);
  return l10n.walkTo(leg.to.name);
}

/// What follows the leg at [legIndex] — "luego: toma la G12", or arrival when
/// that leg is the last one. Null when [legIndex] is out of range.
String? nextStepLabel(AppLocalizations l10n, List<Leg> legs, int legIndex) {
  if (legIndex < 0 || legIndex >= legs.length) return null;
  if (legIndex == legs.length - 1) return l10n.nextStepArrive;
  return l10n.nextStep(legInstruction(l10n, legs[legIndex + 1]));
}
