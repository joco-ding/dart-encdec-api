# Ubuntu-based Dart build environment
# Use linux/amd64 platform explicitly
FROM --platform=linux/amd64 ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies including 32-bit libraries for compatibility
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    ca-certificates \
    libc6 \
    libstdc++6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download and install Dart SDK
RUN curl -fsSL https://storage.googleapis.com/dart-archive/channels/stable/release/3.9.2/sdk/dartsdk-linux-x64-release.zip -o /tmp/dart.zip \
    && unzip -q /tmp/dart.zip -d /opt \
    && rm /tmp/dart.zip

# Add Dart to PATH
ENV PATH="/opt/dart-sdk/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy project files
COPY pubspec.yaml ./
COPY pubspec.lock ./
COPY bin bin/
COPY lib lib/

# Install dependencies
RUN dart pub get

# AOT compile for Linux x64 (produces native executable)
RUN dart compile exe bin/encrypt_decrypt.dart -o /app/encrypt_decrypt

# Expose the port
EXPOSE 8080

# Run the compiled executable
CMD ["/app/encrypt_decrypt"]
