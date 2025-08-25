# Intel QSV Hardware Transcoding Docker Container

A minimal, optimized Docker container for Intel QuickSync (QSV) hardware-accelerated video transcoding using FFmpeg.

## Features

- **Intel QSV Support**: Full hardware acceleration for encoding/decoding
- **Modern Codec Support**: H.264, HEVC, AV1, VP9 with QSV acceleration
- **OneVPL & MediaSDK**: Support for both modern (11th gen+) and legacy Intel GPUs

## Prerequisites

- Docker installed on host system
- Intel GPU with QuickSync support (Intel HD Graphics 2000+)
- Intel GPU drivers installed on host
- Access to `/dev/dri` device

## Quick Start

### 1. Build the Container

Or manually:
```bash
docker build -t qsv-transcoder .
```

### 2. Test QSV Availability

```bash
docker run --rm --device=/dev/dri:/dev/dri qsv-transcoder --check
```

### 3. Test with Sample Video

Download and test with a sample video file:

```bash
# Download test video
wget https://ssh.us-east-1.linodeobjects.com/ribblehead_1080p_h264.mp4 -O /tmp/test_video.mp4

# Run QSV transcoding test
docker run --rm \
  --device=/dev/dri:/dev/dri \
  -v /tmp:/input:ro \
  qsv-transcoder \
  -hwaccel qsv \
  -c:v h264_qsv \
  -i /input/test_video.mp4 \
  -c:v h264_qsv \
  -preset medium \
  -global_quality 25 \
  -f null -
```

Expected output should show:
- QSV hardware acceleration working (`libva info: va_openDriver() returns 0`)
- Processing speed >100 fps for 1080p content
- Using h264_qsv encoder/decoder

### 4. Transcode a Video

```bash
docker run --rm \
  --device=/dev/dri:/dev/dri \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  qsv-transcoder \
  -i /input/video.mp4 \
  -c:v h264_qsv -preset medium -global_quality 25 \
  /output/transcoded.mp4
```

## Usage Examples

### H.264 Encoding with QSV

```bash
docker run --rm \
  --device=/dev/dri:/dev/dri \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  qsv-transcoder \
  -i /input/source.mp4 \
  -c:v h264_qsv \
  -preset medium \
  -global_quality 25 \
  -c:a copy \
  /output/h264_output.mp4
```

### HEVC/H.265 Encoding with Hardware Decode

```bash
docker run --rm \
  --device=/dev/dri:/dev/dri \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  qsv-transcoder \
  -hwaccel qsv -c:v h264_qsv \
  -i /input/source.mp4 \
  -c:v hevc_qsv \
  -preset slow \
  -global_quality 28 \
  -c:a libopus -b:a 128k \
  /output/hevc_output.mp4
```

### AV1 Encoding (Arc GPUs and newer)

```bash
docker run --rm \
  --device=/dev/dri:/dev/dri \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  qsv-transcoder \
  -i /input/source.mp4 \
  -c:v av1_qsv \
  -preset medium \
  -global_quality 30 \
  -c:a copy \
  /output/av1_output.mp4
```

### Full Hardware Pipeline

```bash
docker run --rm \
  --device=/dev/dri:/dev/dri \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  qsv-transcoder \
  -hwaccel qsv -hwaccel_output_format qsv \
  -c:v h264_qsv \
  -i /input/source.mp4 \
  -vf "scale_qsv=1920:1080" \
  -c:v h264_qsv \
  -preset medium \
  -global_quality 25 \
  -c:a copy \
  /output/scaled_output.mp4
```

## Docker Compose

Use the included `docker-compose.yml` for easier management:

```bash
# Check QSV support
docker-compose --profile test up qsv-test

# Run transcoding
docker-compose run --rm qsv-transcoder \
  -i /input/video.mp4 \
  -c:v h264_qsv -preset medium -global_quality 25 \
  /output/transcoded.mp4

# Batch processing (requires scripts/batch-transcode.sh)
docker-compose --profile batch up qsv-batch
```

## Supported Codecs

### Encoders
- `h264_qsv` - H.264/AVC
- `hevc_qsv` - H.265/HEVC
- `av1_qsv` - AV1 (Arc GPUs, 11th gen+)
- `vp9_qsv` - VP9 (limited support)
- `mjpeg_qsv` - Motion JPEG

### Decoders
- `h264_qsv` - H.264/AVC
- `hevc_qsv` - H.265/HEVC
- `av1_qsv` - AV1
- `vp9_qsv` - VP9
- `mpeg2_qsv` - MPEG-2
- `vc1_qsv` - VC-1
- `mjpeg_qsv` - Motion JPEG

## QSV Encoding Parameters

### Quality Control
- **CQP (Constant QP)**: `-q:v 25` (lower = better quality)
- **ICQ (Intelligent CQ)**: `-global_quality 25` (recommended)
- **VBR**: `-b:v 5M -maxrate 10M`
- **CBR**: `-b:v 5M -maxrate 5M -minrate 5M`

### Presets
- `veryfast`, `faster`, `fast`, `medium`, `slow`, `slower`, `veryslow`
- Default: `medium`

### Performance Options
- `-async_depth N`: Set async depth (default: 4)
- `-look_ahead 1`: Enable lookahead
- `-look_ahead_depth N`: Lookahead buffer size

## Troubleshooting

### Check GPU Support

```bash
# On host system
ls -la /dev/dri/
vainfo
```

### Verify Container QSV Access

```bash
docker run --rm --device=/dev/dri:/dev/dri qsv-transcoder \
  -hwaccels

docker run --rm --device=/dev/dri:/dev/dri qsv-transcoder \
  -encoders | grep qsv
```

### Common Issues

1. **"No VA display found"**
   - Ensure `--device=/dev/dri:/dev/dri` is included
   - Check Intel GPU drivers on host

2. **"Failed to initialize QSV"**
   - Verify Intel GPU support: `intel_gpu_top` on host
   - Update Intel graphics drivers

3. **Permission Denied on /dev/dri**
   - Add user to `video` or `render` group on host
   - Run container with appropriate user/group

4. **Codec Not Available**
   - Some codecs require specific GPU generations
   - AV1 requires Arc or 11th gen+ Intel CPUs

## Performance Tips

1. **Use Hardware Decode + Encode**:
   ```bash
   -hwaccel qsv -c:v h264_qsv -i input.mp4 -c:v hevc_qsv output.mp4
   ```

2. **Keep Processing on GPU**:
   ```bash
   -hwaccel_output_format qsv -vf "scale_qsv=1920:1080"
   ```

3. **Optimize Async Depth**:
   ```bash
   -async_depth 8  # Increase for better throughput
   ```

4. **Use ICQ for Quality**:
   ```bash
   -global_quality 25  # Better than CQP for most cases
   ```

## Building from Source

The container uses a multi-stage build to compile FFmpeg with QSV support:

1. **Stage 1**: Builds Intel Media Driver, OneVPL, MediaSDK, and FFmpeg
2. **Stage 2**: Creates minimal runtime with only necessary libraries

Build time: ~15-30 minutes depending on CPU
Runtime image size: ~500MB

## License

This project is provided as-is for video transcoding purposes. FFmpeg and Intel Media components are subject to their respective licenses.

## Contributing

Issues and pull requests are welcome. Please test changes with actual Intel QSV hardware before submitting.