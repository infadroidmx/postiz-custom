#!/bin/bash
set -e

# Configuration
REPO_URL="https://github.com/infadroidmx/postiz-custom.git"
IMAGE_NAME="ghcr.io/infadroidmx/infinate-post"
GH_USER="infadroidmx"
GH_TOKEN="${GH_TOKEN:-}"

echo "🚀 Starting Postiz Deployment Update..."

# Check requirements
if ! command -v docker &> /dev/null; then
    echo "❌ Error: docker is not installed."
    exit 1
fi

# Handle cloning/pulling
if [ -d "postiz-custom" ]; then
    echo "🔄 Updating existing repository..."
    cd postiz-custom && git pull
elif [[ $(basename "$PWD") == "postiz-custom" ]]; then
    echo "🔄 Currently inside postiz-custom, pulling updates..."
    git pull
else
    echo "📥 Cloning repository..."
    if [ -z "$GH_TOKEN" ]; then
        echo "⚠️  Warning: GH_TOKEN not set. Attempting public clone..."
        git clone "$REPO_URL" postiz-custom
    else
        git clone "https://${GH_USER}:${GH_TOKEN}@github.com/infadroidmx/postiz-custom.git" postiz-custom
    fi
    cd postiz-custom
fi

# Build the Docker image
echo "🏗️  Building the optimized Docker image (Multi-stage)..."
docker build -t "${IMAGE_NAME}:latest" -f Dockerfile.dev .

# Login and Push if token is available
if [ -n "$GH_TOKEN" ]; then
    echo "🔑 Logging in to GHCR..."
    echo "${GH_TOKEN}" | docker login ghcr.io -u "${GH_USER}" --password-stdin
    echo "📤 Pushing image..."
    docker push "${IMAGE_NAME}:latest"
else
    echo "⏭️  Skipping push (GH_TOKEN not set)."
fi

echo "✅ Deployment update complete! The image is now smaller and ready."
