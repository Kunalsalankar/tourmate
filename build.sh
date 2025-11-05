#!/bin/bash
set -e

# Install Flutter if not exists
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Verify Flutter installation
flutter --version

# Get dependencies
flutter pub get

# Build web app
flutter build web --release --web-renderer canvaskit
