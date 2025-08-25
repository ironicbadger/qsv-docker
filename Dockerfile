FROM ubuntu:24.04

# Install Intel drivers, Media SDK, and FFmpeg with QSV support
RUN apt-get update && apt-get install -y \
    ffmpeg \
    intel-media-va-driver-non-free \
    libmfx1 \
    libmfx-tools \
    libmfx-gen1.2 \
    libvpl2 \
    intel-opencl-icd \
    vainfo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create working directories
RUN mkdir -p /input /output

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set environment variables for Intel graphics and QSV
ENV LIBVA_DRIVER_NAME=iHD
ENV LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
ENV MFX_HOME=/opt/intel/mediasdk

WORKDIR /output

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]