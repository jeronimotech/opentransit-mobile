#!/usr/bin/env bash
# Guard the one derivation that silently wrecked a signing run.
#
#   tool/check_bundle_ids.sh
#
# testflight.sh derives the app's bundle id from the Xcode project and builds every companion's id
# and profile name from it. It used to take the first PRODUCT_BUNDLE_IDENTIFIER in file order, which
# was right only while Runner's configurations happened to sit first. Adding the share extension put
# its block above Runner's: BUNDLE_ID became com.jeronimotech.opentransit.Share, every companion id
# was derived from that, and the run created four junk bundle ids and replaced three working
# profiles with ones bound to them — in a real Apple Developer account, with nothing in the output
# that looked like an error.
#
# The app's id is the shortest, because every companion is it plus a suffix. This checks that the
# derivation still agrees with that, whatever order the project file ends up in.
set -euo pipefail
cd "$(dirname "$0")/.."
PBXPROJ=ios/Runner.xcodeproj/project.pbxproj

ids=$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+' "$PBXPROJ" | grep -v RunnerTests \
      | sed 's/.*= //' | sort -u)
derived=$(echo "$ids" | awk '{ print length, $0 }' | sort -n | head -n 1 | cut -d' ' -f2-)

fail=0
for id in $ids; do
  case "$id" in
    "$derived") ;;
    "$derived".*) ;;
    *) echo "FAIL: $id is not $derived or a suffix of it" >&2; fail=1 ;;
  esac
done

if [ "$fail" -eq 0 ]; then
  echo "app bundle id: $derived"
  echo "$ids" | grep -v "^$derived\$" | sed 's/^/  companion: /'
else
  echo "the derivation in testflight.sh would pick the wrong id" >&2
fi
exit "$fail"
