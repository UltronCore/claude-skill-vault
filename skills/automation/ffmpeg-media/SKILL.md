---
name: ffmpeg-media
description: >
  FFmpeg media processing: video transcoding, thumbnail extraction, audio processing, and batch operations. Triggers on: ffmpeg, ffprobe, -vcodec, -acodec, -vf, HLS, mp4, WebM, thumbnail, video compress, gif from video.
---

# FFmpeg Media Processing

## When to Use
Use this skill whenever the task involves video/audio conversion, compression, thumbnail generation, HLS streaming output, GIF creation, frame extraction, or any batch media pipeline using ffmpeg or ffprobe.

---

## Core Rules
- Always probe input first with `ffprobe` before deciding encoding params.
- Prefer hardware-accelerated encoding (`videotoolbox` on macOS, `h264_nvenc` on NVIDIA) for speed; fall back to libx264/libx265 for portability.
- Use `-movflags +faststart` for web-optimized MP4s (moov atom at front).
- Avoid re-encoding when only container remux is needed (`-c copy`).
- Add `-y` to overwrite output without prompting in scripts.

---

## Basic Syntax

```bash
ffmpeg -i input.mp4 [options] output.mp4

# Probe file metadata
ffprobe -v quiet -print_format json -show_streams -show_format input.mp4 | jq .
```

---

## Video Transcoding

### H.264 (universal compatibility)
```bash
ffmpeg -i input.mp4 \
  -vcodec libx264 \
  -crf 23 \            # 18=visually lossless, 28=decent quality, 23=default
  -preset slow \       # slow=better compression, fast=faster encode
  -acodec aac -b:a 128k \
  -movflags +faststart \
  output_h264.mp4
```

### H.265 / HEVC (50% smaller than H.264 at same quality)
```bash
ffmpeg -i input.mp4 \
  -vcodec libx265 \
  -crf 28 \
  -preset slow \
  -acodec aac -b:a 128k \
  -tag:v hvc1 \        # required for iOS/macOS compatibility
  output_h265.mp4
```

### VP9 (open-source, great for web)
```bash
ffmpeg -i input.mp4 \
  -vcodec libvpx-vp9 \
  -crf 31 -b:v 0 \     # constant quality mode
  -acodec libopus -b:a 96k \
  output.webm
```

### AV1 (best compression, slow encode)
```bash
ffmpeg -i input.mp4 \
  -vcodec libaom-av1 \
  -crf 30 -b:v 0 \
  -cpu-used 4 \        # 0=slowest/best, 8=fastest
  -acodec libopus \
  output.mp4
```

### macOS hardware acceleration (VideoToolbox)
```bash
ffmpeg -i input.mp4 \
  -vcodec h264_videotoolbox \
  -b:v 5M \
  -acodec aac \
  output_hw.mp4
```

---

## Compress Video for Web

```bash
# Target ~1080p, web-safe, fast start
ffmpeg -i input.mp4 \
  -vf "scale=-2:1080" \   # -2 keeps aspect ratio, divisible by 2
  -vcodec libx264 \
  -crf 26 \
  -preset medium \
  -acodec aac -b:a 128k \
  -movflags +faststart \
  output_web.mp4

# Aggressive compression — mobile/bandwidth constrained
ffmpeg -i input.mp4 \
  -vf "scale=-2:720" \
  -vcodec libx264 -crf 30 -preset slow \
  -acodec aac -b:a 96k \
  -movflags +faststart \
  output_mobile.mp4
```

---

## HLS Streaming Output

```bash
mkdir -p hls_output

ffmpeg -i input.mp4 \
  -vcodec libx264 -crf 22 -preset fast \
  -acodec aac -b:a 128k \
  -hls_time 6 \           # segment duration in seconds
  -hls_list_size 0 \      # 0 = keep all segments in playlist
  -hls_segment_filename "hls_output/segment_%03d.ts" \
  hls_output/playlist.m3u8

# Multi-bitrate HLS (adaptive streaming)
ffmpeg -i input.mp4 \
  -map 0:v -map 0:a -map 0:v -map 0:a \
  -vcodec:v:0 libx264 -b:v:0 3000k \
  -vcodec:v:1 libx264 -b:v:1 800k \
  -acodec:a:0 aac -b:a:0 128k \
  -acodec:a:1 aac -b:a:1 96k \
  -var_stream_map "v:0,a:0 v:1,a:1" \
  -master_pl_name master.m3u8 \
  -hls_time 6 \
  -hls_segment_filename "hls_output/stream_%v_%03d.ts" \
  hls_output/stream_%v.m3u8
```

---

## Thumbnail / Poster Extraction

```bash
# Single thumbnail at timestamp
ffmpeg -i input.mp4 -ss 00:00:05 -frames:v 1 thumbnail.jpg

# High quality thumbnail
ffmpeg -i input.mp4 -ss 00:00:05 -frames:v 1 -q:v 2 thumbnail.jpg

# Extract frame every N seconds
ffmpeg -i input.mp4 -vf "fps=1/10" frames/frame_%04d.jpg

# Best-quality thumbnail (seek to ~10% in)
ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 input.mp4
# Then use 10% of that duration as -ss value

# Grid of thumbnails (tile)
ffmpeg -i input.mp4 \
  -vf "fps=1/30,scale=320:-1,tile=4x4" \
  -frames:v 1 \
  thumbnail_grid.jpg
```

---

## Audio Processing

```bash
# Extract audio only
ffmpeg -i input.mp4 -vn -acodec libmp3lame -b:a 192k output.mp3
ffmpeg -i input.mp4 -vn -acodec aac -b:a 256k output.m4a
ffmpeg -i input.mp4 -vn -acodec flac output.flac

# Normalize audio
ffmpeg -i input.mp4 -af "loudnorm=I=-16:TP=-1.5:LRA=11" output_normalized.mp4

# Trim audio/video
ffmpeg -i input.mp4 -ss 00:00:30 -to 00:02:00 -c copy trimmed.mp4

# Remove audio track
ffmpeg -i input.mp4 -an -vcodec copy no_audio.mp4

# Mix two audio tracks
ffmpeg -i video.mp4 -i music.mp3 \
  -filter_complex "[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=2" \
  -vcodec copy output_mixed.mp4
```

---

## GIF from Video

```bash
# Fast GIF (lower quality, smaller file)
ffmpeg -i input.mp4 -ss 00:00:02 -t 5 \
  -vf "fps=10,scale=480:-1" \
  output.gif

# High quality GIF (palette-based)
ffmpeg -i input.mp4 -ss 00:00:02 -t 5 \
  -vf "fps=15,scale=480:-1:flags=lanczos,palettegen" \
  palette.png

ffmpeg -i input.mp4 -i palette.png -ss 00:00:02 -t 5 \
  -filter_complex "fps=15,scale=480:-1:flags=lanczos[x];[x][1:v]paletteuse" \
  output_hq.gif

# One-liner HQ GIF (zsh/bash)
INPUT=input.mp4; START=0; DUR=5; OUT=output.gif
ffmpeg -i "$INPUT" -ss $START -t $DUR -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" "$OUT"
```

---

## Extract Frames (Batch)

```bash
# Extract all frames as PNG
ffmpeg -i input.mp4 frames/frame_%05d.png

# Extract at specific FPS
ffmpeg -i input.mp4 -vf "fps=2" frames/frame_%05d.jpg

# Extract only keyframes (I-frames)
ffmpeg -i input.mp4 -vf "select=eq(pict_type\,I)" -vsync vfr frames/keyframe_%04d.jpg
```

---

## Batch Processing with Shell Loops

```bash
# Convert all MOV files to MP4 in current directory
for f in *.MOV; do
  ffmpeg -i "$f" \
    -vcodec libx264 -crf 23 -preset medium \
    -acodec aac -b:a 128k \
    -movflags +faststart \
    "${f%.MOV}.mp4"
done

# Batch thumbnail extraction
for f in *.mp4; do
  ffmpeg -i "$f" -ss 00:00:03 -frames:v 1 \
    "thumbs/${f%.mp4}.jpg"
done

# Parallel batch (GNU parallel)
ls *.mp4 | parallel 'ffmpeg -i {} -vcodec libx264 -crf 26 converted/{.}_web.mp4'
```

---

## ffprobe — Metadata Inspection

```bash
# Duration and basic info
ffprobe -v quiet -print_format json -show_format input.mp4 | jq '{duration: .format.duration, size: .format.size, bitrate: .format.bit_rate}'

# Video stream details
ffprobe -v quiet -print_format json -show_streams -select_streams v input.mp4 | jq '.streams[0] | {codec: .codec_name, width, height, fps: .r_frame_rate, bitrate: .bit_rate}'

# Audio stream details
ffprobe -v quiet -print_format json -show_streams -select_streams a input.mp4 | jq '.streams[0] | {codec: .codec_name, sample_rate, channels}'

# Quick one-line summary
ffprobe -v error -show_entries format=duration,size,bit_rate -of default=noprint_wrappers=1 input.mp4
```

---

## Common Video Filters (-vf)

```bash
# Resize (keep aspect)
-vf "scale=1280:-2"

# Crop (width:height:x:y)
-vf "crop=1280:720:0:60"

# Rotate
-vf "transpose=1"   # 0=ccw+flip, 1=cw, 2=ccw, 3=cw+flip

# Fade in/out
-vf "fade=in:0:30,fade=out:270:30"   # 30 frames fade at start and near end

# Add text overlay
-vf "drawtext=text='Hello World':fontsize=48:fontcolor=white:x=10:y=10"

# Stack two videos side by side
-filter_complex "[0:v][1:v]hstack=inputs=2"

# Speed up / slow down
-filter:v "setpts=0.5*PTS"   # 2x speed
-filter:v "setpts=2.0*PTS"   # 0.5x speed (slow mo)
```

---

## Quick Reference — Common Recipes

| Task | Command snippet |
|------|----------------|
| Remux MKV → MP4 | `ffmpeg -i in.mkv -c copy out.mp4` |
| Cut without re-encode | `ffmpeg -i in.mp4 -ss 00:01:00 -to 00:02:30 -c copy out.mp4` |
| Add subtitles (burn-in) | `ffmpeg -i in.mp4 -vf subtitles=subs.srt out.mp4` |
| Concat files | `ffmpeg -f concat -safe 0 -i filelist.txt -c copy out.mp4` |
| Two-pass encode | See H.264 2-pass below |

### Two-Pass H.264 (best quality at target bitrate)
```bash
ffmpeg -i input.mp4 -vcodec libx264 -b:v 2000k -pass 1 -an -f null /dev/null
ffmpeg -i input.mp4 -vcodec libx264 -b:v 2000k -pass 2 -acodec aac output.mp4
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/automation/ffmpeg-media/.gitnexus
Last indexed: 2026-05-23
