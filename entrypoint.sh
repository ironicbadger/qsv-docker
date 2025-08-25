#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_device_access() {
    if [ ! -e /dev/dri ]; then
        log_error "/dev/dri not found. Please run container with --device=/dev/dri:/dev/dri"
        exit 1
    fi

    if [ ! -r /dev/dri/renderD128 ] && [ ! -r /dev/dri/renderD129 ]; then
        log_warning "No render devices found. QSV may not be available."
    fi

    if ! groups | grep -q video && ! groups | grep -q render; then
        log_warning "Current user not in video/render group. Adding to groups..."
        usermod -a -G video,render ffmpeg 2>/dev/null || true
    fi
}

check_qsv_availability() {
    log_info "Checking Intel QSV availability..."
    
    if ! vainfo 2>&1 | grep -q "Driver version"; then
        log_error "VA-API driver not properly initialized"
        log_error "Output from vainfo:"
        vainfo 2>&1
        exit 1
    fi
    
    vainfo 2>&1 | grep "Driver version" | head -1
    
    if ! ffmpeg -hide_banner -hwaccels 2>&1 | grep -q "qsv"; then
        log_warning "QSV hardware acceleration not detected by FFmpeg"
        log_warning "Available hardware accelerations:"
        ffmpeg -hide_banner -hwaccels
    else
        log_info "QSV hardware acceleration is available"
    fi
    
    log_info "Available QSV encoders:"
    ffmpeg -hide_banner -encoders 2>/dev/null | grep qsv | sed 's/^/  /'
    
    log_info "Available QSV decoders:"
    ffmpeg -hide_banner -decoders 2>/dev/null | grep qsv | sed 's/^/  /'
}

validate_paths() {
    if [ ! -d /input ]; then
        log_warning "/input directory not mounted"
    fi
    
    if [ ! -d /output ]; then
        log_warning "/output directory not mounted"
    fi
    
    for arg in "$@"; do
        if [[ "$arg" == /input/* ]]; then
            if [ ! -e "$arg" ]; then
                log_error "Input file not found: $arg"
                log_error "Please ensure the file exists in the mounted /input directory"
                exit 1
            fi
        fi
    done
}

print_usage() {
    cat << EOF
Intel QSV FFmpeg Transcoder Container

Usage: docker run --rm \\
         --device=/dev/dri:/dev/dri \\
         -v /host/input:/input:ro \\
         -v /host/output:/output \\
         qsv-transcoder [FFMPEG_OPTIONS]

Examples:
  # Basic H.264 QSV encoding
  docker run --rm \\
    --device=/dev/dri:/dev/dri \\
    -v \$(pwd)/videos:/input:ro \\
    -v \$(pwd)/output:/output \\
    qsv-transcoder \\
    -i /input/source.mp4 \\
    -c:v h264_qsv -preset medium -global_quality 25 \\
    /output/encoded.mp4

  # HEVC encoding with hardware decode
  docker run --rm \\
    --device=/dev/dri:/dev/dri \\
    -v \$(pwd)/videos:/input:ro \\
    -v \$(pwd)/output:/output \\
    qsv-transcoder \\
    -hwaccel qsv -c:v h264_qsv \\
    -i /input/source.mp4 \\
    -c:v hevc_qsv -preset slow -global_quality 28 \\
    /output/encoded.mp4

  # Check QSV support
  docker run --rm \\
    --device=/dev/dri:/dev/dri \\
    qsv-transcoder \\
    -hwaccels

EOF
}

main() {
    if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        print_usage
        check_device_access
        check_qsv_availability
        exit 0
    fi
    
    # Skip device check for version/help/info queries or when not using QSV
    if [[ " $* " =~ " _qsv " ]] || [[ " $* " =~ " -hwaccel qsv " ]] || [[ " $* " =~ " -hwaccel_device " ]]; then
        check_device_access
    fi
    
    if [ "$1" = "--check" ] || [ "$1" = "check" ]; then
        check_device_access
        check_qsv_availability
        exit 0
    fi
    
    validate_paths "$@"
    
    if [[ ! " $* " =~ " -hwaccels " ]] && [[ ! " $* " =~ " -encoders " ]] && [[ ! " $* " =~ " -decoders " ]]; then
        log_info "Starting FFmpeg with QSV support..."
        log_info "Command: ffmpeg $@"
        echo "----------------------------------------"
    fi
    
    exec ffmpeg "$@"
}

main "$@"