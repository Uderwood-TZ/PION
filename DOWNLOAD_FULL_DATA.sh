#!/usr/bin/env bash

set -euo pipefail

REPO="Uderwood-TZ/PION"
TAG="full-data-v1"
BASE="https://github.com/${REPO}/releases/download/${TAG}"

START_DIR="$(pwd)"
ROOT="${1:-$START_DIR/PION_FULL_RESTORE}"
PARTDIR="$ROOT/parts"
TARGET="$ROOT/restored"

mkdir -p "$PARTDIR" "$TARGET"

echo "======================================================"
echo " PION FULL DATA DOWNLOADER AND RESTORER"
echo "======================================================"
echo "Release : $TAG"
echo "Parts   : $PARTDIR"
echo "Restore : $TARGET"
echo

CURL_BASE=(
    curl
    -fL
    --http1.1
    --retry 50
    --retry-delay 5
    --retry-all-errors
    --connect-timeout 30
)

echo "[1/5] Downloading checksum and manifest..."

"${CURL_BASE[@]}" \
    -o "$PARTDIR/PION-full.sha256" \
    "$BASE/PION-full.sha256"

"${CURL_BASE[@]}" \
    -o "$PARTDIR/FULL_DATA_MANIFEST.tsv" \
    "$BASE/FULL_DATA_MANIFEST.tsv"

echo "[OK] Metadata downloaded."
echo

echo "[2/5] Downloading all archive parts..."

cd "$PARTDIR"

while read -r HASH FILE; do

    [ -n "${FILE:-}" ] || continue

    if [ -f "$FILE" ] && \
       printf '%s  %s\n' "$HASH" "$FILE" | sha256sum -c - >/dev/null 2>&1; then

        echo "[SKIP] $FILE already complete."
        continue
    fi

    echo
    echo "Downloading $FILE ..."

    if ! "${CURL_BASE[@]}" \
        -C - \
        -o "$FILE" \
        "$BASE/$FILE"; then

        echo "[WARN] Resume failed for $FILE."
        echo "[INFO] Restarting this part from zero..."

        rm -f "$FILE"

        "${CURL_BASE[@]}" \
            -o "$FILE" \
            "$BASE/$FILE"
    fi

    if ! printf '%s  %s\n' "$HASH" "$FILE" | sha256sum -c -; then

        echo "[WARN] Checksum mismatch."
        echo "[INFO] Re-downloading $FILE from zero..."

        rm -f "$FILE"

        "${CURL_BASE[@]}" \
            -o "$FILE" \
            "$BASE/$FILE"

        printf '%s  %s\n' "$HASH" "$FILE" | sha256sum -c -
    fi

done < PION-full.sha256

echo
echo "[OK] All archive parts downloaded."
echo

echo "[3/5] Verifying every archive part..."

sha256sum -c PION-full.sha256

echo
echo "[OK] All SHA-256 checks passed."
echo

echo "[4/5] Restoring original PION directory tree..."

rm -rf "$TARGET"
mkdir -p "$TARGET"

cat "$PARTDIR"/PION-full.tar.part-* | \
    tar -xf - -C "$TARGET"

echo
echo "[OK] Archive extracted."
echo

echo "[5/5] Checking restored file count and total bytes..."

EXPECTED_FILES="$(
    wc -l < "$PARTDIR/FULL_DATA_MANIFEST.tsv" |
    tr -d ' '
)"

EXPECTED_BYTES="$(
    awk -F '\t' \
    '{s += $1} END {printf "%.0f", s}' \
    "$PARTDIR/FULL_DATA_MANIFEST.tsv"
)"

ACTUAL_FILES="$(
    find "$TARGET" -type f |
    wc -l |
    tr -d ' '
)"

ACTUAL_BYTES="$(
    find "$TARGET" -type f -printf '%s\n' |
    awk '{s += $1} END {printf "%.0f", s}'
)"

echo
echo "Expected files : $EXPECTED_FILES"
echo "Restored files : $ACTUAL_FILES"
echo
echo "Expected bytes : $EXPECTED_BYTES"
echo "Restored bytes : $ACTUAL_BYTES"
echo

if [ "$EXPECTED_FILES" != "$ACTUAL_FILES" ]; then
    echo "ERROR: File-count verification failed."
    exit 20
fi

if [ "$EXPECTED_BYTES" != "$ACTUAL_BYTES" ]; then
    echo "ERROR: Total-byte verification failed."
    exit 21
fi

for DIR in FVM PINN PION R-PINN XPINN; do
    if [ ! -d "$TARGET/$DIR" ]; then
        echo "ERROR: Missing restored directory: $DIR"
        exit 22
    fi
done

echo
echo "======================================================"
echo " ALL PION DATA RESTORED SUCCESSFULLY"
echo "======================================================"
echo
echo "Restored location:"
echo "$TARGET"
echo
echo "Verified directories:"
echo "  FVM/"
echo "  PINN/"
echo "  PION/"
echo "  R-PINN/"
echo "  XPINN/"
echo
echo "All archive SHA-256 checks passed."
echo "File count and total byte count match the manifest."
echo "======================================================"
