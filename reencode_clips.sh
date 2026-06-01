#!/bin/bash
# Re-encodes existing clips to HEVC 540p CRF 32 with audio passthrough.
# Skips files that are already HEVC-encoded (idempotent).

CLIPS_DIR="/Users/annguyen/Documents/MediaListeningSRS/clips"
FFMPEG="/opt/homebrew/bin/ffmpeg"

if [ ! -x "$FFMPEG" ]; then
  echo "ERROR: ffmpeg not found at $FFMPEG"
  exit 1
fi

total=0
skipped=0
encoded=0
failed=0

for mp4 in "$CLIPS_DIR"/**/*.mp4; do
  [ -f "$mp4" ] || continue
  total=$((total + 1))

  codec=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$mp4" 2>/dev/null)
  if [ "$codec" = "hevc" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  before_size=$(stat -f%z "$mp4")
  tmp="${mp4%.mp4}.tmp.mp4"

  if "$FFMPEG" -y -i "$mp4" -vf scale=-2:540 -c:v libx265 -crf 32 -preset fast -tag:v hvc1 -c:a copy "$tmp" 2>/dev/null; then
    mv "$tmp" "$mp4"
    after_size=$(stat -f%z "$mp4")
    savings=$(( (before_size - after_size) * 100 / before_size ))
    printf "[%d/%d] %s  %d KB → %d KB  (-%d%%)\n" "$((skipped + encoded + failed))" "$total" "$(basename "$mp4")" "$((before_size/1024))" "$((after_size/1024))" "$savings"
    encoded=$((encoded + 1))
  else
    rm -f "$tmp"
    echo "FAILED: $mp4"
    failed=$((failed + 1))
  fi
done

echo ""
echo "Done. total=$total encoded=$encoded skipped=$skipped failed=$failed"
