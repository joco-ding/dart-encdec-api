#!/bin/bash

# Upload script to deploy project to production server using rsync
# Server OS: Ubuntu

# ============================================
# CONFIGURATION - Edit these values
# ============================================

# Server connection details
SERVER_HOST="10.11.12.149"          # Replace with your server IP or hostname
SERVER_USER="deployer"          # Replace with your SSH username
SERVER_PORT="22"                      # SSH port (default: 22)

# Remote server paths
REMOTE_DEPLOY_PATH="/opt/enc_dec" # Replace with your deployment directory
REMOTE_WEB_ROOT="/opt/enc_dec"   # Web root directory (for symlinks if needed)

# Local project directory (relative to script location)
PROJECT_DIR="."

# Files/directories to exclude from upload
EXCLUDE_FILE=".rsyncignore"

# ============================================
# SCRIPT LOGIC
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if rsync is installed
if ! command -v rsync &> /dev/null; then
    print_error "rsync is not installed. Install it with: brew install rsync (macOS) or sudo apt install rsync (Ubuntu)"
    exit 1
fi

# Check SSH connection
print_info "Checking SSH connection to $SERVER_USER@$SERVER_HOST..."

if ! ssh -p $SERVER_PORT -o ConnectTimeout=5 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" "echo 'Connection OK'" &> /dev/null; then
    print_error "Cannot connect to server. Please check your SSH credentials and server settings."
    exit 1
fi

print_info "SSH connection successful!"

# Create remote directory if it doesn't exist
print_info "Creating remote directory if needed..."
ssh -p $SERVER_PORT "$SERVER_USER@$SERVER_HOST" "mkdir -p $REMOTE_DEPLOY_PATH"

# Sync files using rsync
print_info "Starting rsync upload to $SERVER_USER@$SERVER_HOST:$REMOTE_DEPLOY_PATH..."

rsync -avz \
    --progress \
    -e "ssh -p $SERVER_PORT" \
    --exclude-from='.rsyncignore' \
    --delete \
    $PROJECT_DIR/ \
    "$SERVER_USER@$SERVER_HOST:$REMOTE_DEPLOY_PATH/"

print_info "Upload completed successfully!"
