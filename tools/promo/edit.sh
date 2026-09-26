#!/bin/sh
# Turns tools/promo/record.py's raw capture into the README cover (published as assets of the "media" GitHub Release): the full video (mp4, no audio) and an
# animated WebP for the cover. Needs ffmpeg. Usage: tools/promo/edit.sh [folder with raw.mp4 and marks.json] [output folder]
HERE="$(cd "$(dirname "$0")" && pwd)"
IN="${1:-$HERE/out}"
OUT="${2:-$HERE/out}"
mkdir -p "$OUT"
START=$(python3 -c "import json,sys; m=json.load(open('$IN/marks.json')); print(max(0, m['start']-0.25))")
LEN=$(python3 -c "import json; m=json.load(open('$IN/marks.json')); print(round(m['end']-m['start']+0.25+0.25, 2))")
FADE_OUT=$(python3 -c "print(round($LEN-0.6, 2))")

# the full video: fades in from and out to black, 60 fps, no sound
ffmpeg -v error -y -ss "$START" -t "$LEN" -i "$IN/raw.mp4" -an \
    -vf "fade=t=in:st=0:d=0.35,fade=t=out:st=$FADE_OUT:d=0.5,format=yuv420p" \
    -c:v libx264 -preset slow -crf 20 -movflags +faststart "$OUT/promo.mp4" || exit 1
echo "$OUT/promo.mp4: $(du -h "$OUT/promo.mp4" | cut -f1)"

# the cover: the same video as an animated WebP (a fraction of a GIF's size, and GitHub plays it inline)
ffmpeg -v error -y -i "$OUT/promo.mp4" -an \
    -vf "fps=24,scale=960:-1:flags=lanczos" -c:v libwebp_anim -q:v 60 -compression_level 6 -loop 0 "$OUT/promo.webp" || exit 1
echo "$OUT/promo.webp: $(du -h "$OUT/promo.webp" | cut -f1)"
