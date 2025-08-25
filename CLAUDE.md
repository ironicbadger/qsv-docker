# Intel QSV Hardware Transcoding Docker Project

## Project Overview
Create a minimal, one-shot Docker container for Intel QuickSync (QSV) hardware video transcoding using FFmpeg.

## Key Requirements
- **Development Environment**: All development done inside containers (no host packages)
- **Hardware**: Intel QSV verified working on host system
- **Usage Pattern**: One-shot container that accepts FFmpeg commands at runtime
- **Input/Output**: Volume-mapped for file ingestion and output

## Architecture Components

### 1. Base Image Selection
- Ubuntu 24.04 LTS as base (stable, well-supported)
- Minimal installation to reduce image size
- Multi-stage build to separate build deps from runtime

### 2. Intel Graphics Stack
Required components for QSV:
- **libva** (2.14+): Video Acceleration API
- **intel-media-driver**: VA-API driver for Intel GPUs
- **libdrm**: Direct Rendering Manager library
- **gmmlib**: Intel Graphics Memory Management Library
- **OneVPL** (Intel oneAPI VPL): Modern QSV implementation for 11th gen+
- **MediaSDK**: Legacy QSV support for older Intel GPUs

### 3. FFmpeg Build
Custom FFmpeg compilation with:
- `--enable-libvpl`: OneVPL support
- `--enable-vaapi`: VA-API support
- `--enable-libdrm`: DRM support
- QSV encoders: h264_qsv, hevc_qsv, av1_qsv, vp9_qsv
- QSV decoders: h264_qsv, hevc_qsv, av1_qsv, vp9_qsv, mpeg2_qsv

### 4. Container Runtime
- **Entrypoint**: Wrapper script to handle FFmpeg commands
- **Device Access**: Requires `/dev/dri` device mapping
- **User Permissions**: Handle render group permissions
- **Volume Mounts**: `/input` and `/output` directories

## Usage Design

### Basic Usage Pattern
```bash
docker run --rm \
  --device=/dev/dri:/dev/dri \
  -v /host/input:/input:ro \
  -v /host/output:/output \
  qsv-transcoder \
  -i /input/video.mp4 \
  -c:v h264_qsv \
  -preset medium \
  -global_quality 25 \
  /output/video_transcoded.mp4
```

### Key Features
1. **Direct FFmpeg Pass-through**: Container accepts raw FFmpeg arguments
2. **Automatic QSV Detection**: Entrypoint validates hardware availability
3. **Error Handling**: Clear messages if QSV unavailable or command fails
4. **Flexible Codec Support**: All major QSV codecs available

## File Structure
```
qsv-docker/
├── Dockerfile           # Multi-stage build for QSV FFmpeg
├── entrypoint.sh       # Wrapper script for FFmpeg execution
├─�compose.yml  # Example compose configuration
├── build.sh           # Build automation script
├── README.md          # User documentation
└── CLAUDE.md          # This project plan
```

## Implementation Notes

### Performance Optimizations
- Use hardware decoding when possible (`-hwaccel qsv`)
- Implement hardware upload/download filters for optimal pipeline
- Configure async_depth for better throughput
- Use appropriate preset levels (faster/medium/slower)

### Codec-Specific Considerations
- **H.264**: Use `-global_quality` for quality-based encoding
- **HEVC**: Support HDR metadata preservation
- **AV1**: Available on Arc GPUs and newer
- **VP9**: Limited platform support, check availability

### Error Handling
- Verify `/dev/dri` device availability
- Check for render group permissions
- Fallback messaging if QSV init fails
- Validate input/output paths

## Testing Strategy
1. Build container with test suite
2. Verify QSV encoder/decoder availability
3. Test common transcoding scenarios
4. Validate output quality and performance
5. Check device permission handling

## Future Enhancements
- Preset profiles for common use cases
- Benchmark mode for performance testing

- any containers run should be done so via docker compose. docker-compose is obselete, using `docker compose` instead. and for any container expected to do qsv encoding you must mount /dev/dri device.