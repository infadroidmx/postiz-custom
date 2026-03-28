#!/bin/bash
set -e

# Configuration
REPO_URL="https://github.com/infadroidmx/postiz-custom.git"
IMAGE_NAME="ghcr.io/infadroidmx/infinate-post"
GH_USER="infadroidmx"

# 1. Grab updated Git (Syncs with master branch)
if [ -d "postiz-custom" ]; then
    echo "🔄 Updating repository from origin/master..."
    cd postiz-custom && git fetch origin && git reset --hard origin/master
else
    echo "📥 Repository folder not found. Please ensure you are running this from the server root."
    echo "If you need to clone, use: git clone https://<TOKEN>@github.com/infadroidmx/postiz-custom.git postiz-custom"
    exit 1
fi

# 2. Create Docker (Uses our new optimized Dockerfile.dev)
echo "🏗️  Building Docker image..."
docker build -t "${IMAGE_NAME}:latest" -f Dockerfile.dev .

# 3. Upload Updated Image
echo "🔑 Logging in to GHCR..."
# Ensure GH_TOKEN is set in your environment
if [ -z "$GH_TOKEN" ]; then
    echo "❌ Error: GH_TOKEN is not set. Please run: export GH_TOKEN=your_token_here"
    exit 1
fi

echo "${GH_TOKEN}" | docker login ghcr.io -u "${GH_USER}" --password-stdin
echo "📤 Pushing image..."
docker push "${IMAGE_NAME}:latest"

echo "✅ Deployment update complete! Build includes all local master fixes."
