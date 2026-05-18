#!/bin/bash
# Build script for encrypt-decrypt Dart project on Linux (Ubuntu)
# Usage: ./build_linux.sh

set -e

PROJECT_NAME="encrypt-decrypt-app"
OUTPUT_DIR="dist"
OUTPUT_FILE="$OUTPUT_DIR/encrypt_decrypt"

echo "=== Building encrypt-decrypt for Linux/Ubuntu ==="

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build Docker image and compile the executable
echo "Building Docker image..."
docker build -t "$PROJECT_NAME" .

# Create a temporary container to copy the executable
echo "Extracting compiled executable..."
docker create --name temp-build-container "$PROJECT_NAME"

# Copy the executable to the host
docker cp temp-build-container:/app/encrypt_decrypt "$OUTPUT_FILE"

# Clean up the temporary container
docker rm temp-build-container

# Verify the output
if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "=== Build successful! ==="
    echo "Output: $OUTPUT_FILE"
    echo "Size: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
    echo "Type: $(file "$OUTPUT_FILE")"
    echo ""
    echo "To run on Ubuntu:"
    echo "  chmod +x $OUTPUT_FILE"
    echo "  ./$OUTPUT_FILE"
else
    echo "ERROR: Build failed - executable not found"
    exit 1
fi