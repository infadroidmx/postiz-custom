#!/bin/bash
set -e

# Configuration
REPO_URL="https://github.com/infadroidmx/postiz-custom.git"
IMAGE_NAME="ghcr.io/infadroidmx/infinate-posts"
GH_USER="infadroidmx"
GH_TOKEN="${GH_TOKEN:-}" # User should set this in environment

# Handle cloning/pulling
if [ -d "postiz-custom" ]; then
    echo "Updating existing repository..."
    cd postiz-custom && git pull
elif [[ $(basename "$PWD") == "postiz-custom" ]]; then
    echo "Currently inside postiz-custom, pulling updates..."
    git pull
else
    echo "Cloning repository..."
    git clone "https://${GH_USER}:${GH_TOKEN}@github.com/infadroidmx/postiz-custom.git" postiz-custom
    cd postiz-custom
fi

# Build the Docker image
echo "Building the Docker image..."
docker build -t "${IMAGE_NAME}:latest" -f Dockerfile.dev .

# Login and Push
echo "Logging in to GHCR..."
echo "${GH_TOKEN}" | docker login ghcr.io -u "${GH_USER}" --password-stdin
echo "Pushing image..."
docker push "${IMAGE_NAME}:latest"

echo "Deployment update complete."
