#!/bin/bash
# Re-compresses existing thumbnails to 540p height, 60% JPEG quality.
# Uses sips (built-in macOS tool). Idempotent — skips files already ≤540px tall.

CLIPS_DIR="/Users/annguyen/Documents/MediaListeningSRS/clips"

total=0
skipped=0
compressed=0

for jpg in "$CLIPS_DIR"/**/*.jpg; do
  [ -f "$jpg" ] || continue
  total=$((total + 1))

  height=$(sips -g pixelHeight "$jpg" 2>/dev/null | awk '/pixelHeight/{print $2}')
  if [ "$height" -le 540 ] 2>/dev/null; then
    skipped=$((skipped + 1))
    continue
  fi

  before_size=$(stat -f%z "$jpg")

  sips --resampleHeight 540 -s formatOptions 60 "$jpg" --out "$jpg" >/dev/null 2>&1

  after_size=$(stat -f%z "$jpg")
  savings=$(( (before_size - after_size) * 100 / before_size ))
  printf "[%d/%d] %s  %d KB → %d KB  (-%d%%)\n" "$((skipped + compressed))" "$total" "$(basename "$jpg")" "$((before_size/1024))" "$((after_size/1024))" "$savings"
  compressed=$((compressed + 1))
done

echo ""
echo "Done. total=$total compressed=$compressed skipped=$skipped"
