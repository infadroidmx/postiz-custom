#!/bin/bash
set -e

# ==============================================================================
# POSTIZ DEVELOPMENT ENVIRONMENT SETUP SCRIPT
# ==============================================================================
# 
# ⚠️ EDIT THE CONFIGURATION SECTION BELOW TO SET YOUR API KEYS! ⚠️
# Leave a setting as "" if you aren't using it. It won't be added to Postiz!
# ==============================================================================

# --- Cloudflare Settings ---
CLOUDFLARE_ACCOUNT_ID=""
CLOUDFLARE_ACCESS_KEY=""
CLOUDFLARE_SECRET_ACCESS_KEY=""
CLOUDFLARE_BUCKETNAME=""
CLOUDFLARE_BUCKET_URL=""

# --- Email Settings ---
EMAIL_PROVIDER="" # resend or nodemailer
RESEND_API_KEY="" 
EMAIL_HOST=""
EMAIL_PORT=""
EMAIL_SECURE="" 
EMAIL_USER=""
EMAIL_PASS=""

# --- Social Media API Settings ---
X_API_KEY=""
X_API_SECRET=""
LINKEDIN_CLIENT_ID=""
LINKEDIN_CLIENT_SECRET=""
REDDIT_CLIENT_ID=""
REDDIT_CLIENT_SECRET=""
GITHUB_CLIENT_ID=""
GITHUB_CLIENT_SECRET=""

# --- AI Settings ---
OPENAI_API_KEY=""


# ==============================================================================
# ==============================================================================
# SCRIPT LOGIC BELOW (Do not edit unless you know what you are doing)
# ==============================================================================
# ==============================================================================

DIR="/root/postiz-dev"
SECRETS_FILE="$DIR/.postiz_secrets"

echo "==========================================================================="
echo "    POSTIZ INSTALLATION & UPDATE MENU"
echo "==========================================================================="
echo "Do you want to perform a CLEAN install or an UPDATE?"
echo " - clean : Wipes database and completely re-initializes (Fixes Auth Errors)"
echo " - update: Preserves data and just updates the server software"
echo ""
read -p "Type 'clean' or 'update' [default: update]: " INSTALL_MODE
INSTALL_MODE=${INSTALL_MODE:-update}

mkdir -p "$DIR"

# ==============================================================================
# Secrets and Credentials Generation
# ==============================================================================
if [[ "$INSTALL_MODE" == "clean" ]]; then
    echo "    -> Clean install requested! Wiping old secrets and Docker Volumes..."
    rm -f "$SECRETS_FILE"
    
    echo "    -> Force removing any lingering independent Postgres/Redis containers..."
    docker rm -f postgres redis 2>/dev/null || true
    
    if [ -d "$DIR/postiz-docker-compose" ]; then
        cd "$DIR/postiz-docker-compose"
        docker compose down -v || true
        cd "$DIR"
    fi
    
    echo "    -> Deleting existing source code to force a pristine fresh clone..."
    rm -rf "$DIR/postiz-app" 2>/dev/null || true
fi

if [ -f "$SECRETS_FILE" ]; then
    echo "    -> Loading existing Database Credentials and JWT Secret..."
    source "$SECRETS_FILE"
else
    echo "    -> Generating secure DYNAMIC Database Credentials and JWT Secret..."
    # Generate random variables ensuring safety in shell and URLs
    POSTIZ_DB_USER="usr_$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)"
    POSTIZ_DB_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
    POSTIZ_JWT_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
    
    echo "POSTIZ_DB_USER=\"$POSTIZ_DB_USER\"" > "$SECRETS_FILE"
    echo "POSTIZ_DB_PASS=\"$POSTIZ_DB_PASS\"" >> "$SECRETS_FILE"
    echo "POSTIZ_JWT_SECRET=\"$POSTIZ_JWT_SECRET\"" >> "$SECRETS_FILE"
fi

echo "==> [1/9] Checking system dependencies and Server Memory (OOM Protection)..."
# Removed silent failure outputs so that we can actually see if curl fails to install
echo "    -> Updating package lists and forcefully installing curl/wget/git..."
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall curl wget git ca-certificates

echo "    -> Increasing OS file watcher limits (Fixes Next.js OS file watch limit reached)..."
if ! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf 2>/dev/null; then
    echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
else
    sed -i 's/^fs.inotify.max_user_watches.*/fs.inotify.max_user_watches=524288/' /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
fi

echo "    -> Checking System Swap Space (Fixes Exit Code 137 / Out of Memory)..."
if ! swapon --show | grep -q 'swap'; then
    echo "       - No swap file detected! Generating a 4GB Swap File to protect RAM..."
    fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096 status=none
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile >/dev/null 2>&1 || true
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "       - Swap file successfully allocated and mounted!"
else
    echo "       - System Swap is already configured."
fi

echo "==> [2/9] Checking Node.js 18+..."
if ! command -v node &> /dev/null; then
    echo "    -> Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "    -> Node.js is already installed: $(node -v)"
fi

echo "==> [3/9] Checking pnpm..."
if ! command -v pnpm &> /dev/null; then
    echo "    -> Installing pnpm..."
    npm install -g pnpm
else
    echo "    -> pnpm is already installed"
fi

echo "==> [4/9] Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "    -> Installing Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "    -> Docker is already installed"
fi

echo "==> [5/9] Setting up Database, Redis, and Temporal stack..."
cd "$DIR"
if [ ! -d "postiz-docker-compose" ]; then
    echo "    -> Cloning postiz-docker-compose repository..."
    git clone https://github.com/gitroomhq/postiz-docker-compose.git
    cd postiz-docker-compose
else
    echo "    -> Updating postiz-docker-compose repository..."
    cd postiz-docker-compose
    git pull
fi

# We must inject our dynamic credentials and EXPOSE the ports to the host
# so that Prisma (running on your Linux machine) can connect to Postgres (in Docker).
echo "    -> Injecting dynamic database credentials and publishing ports..."
cat << EOF > docker-compose.override.yml
services:
  postiz-postgres:
    environment:
      POSTGRES_USER: $POSTIZ_DB_USER
      POSTGRES_PASSWORD: $POSTIZ_DB_PASS
    ports:
      - "5432:5432"
  postiz-redis:
    ports:
      - "6379:6379"
EOF

echo "    -> Starting Temporal, Redis, and Postgres in the background..."
docker compose up -d postiz-postgres postiz-redis temporal temporal-postgresql temporal-elasticsearch || true

echo "==> [6/9] Setting up postiz-app source code..."
cd "$DIR"
if [ ! -d "postiz-app/.git" ]; then
    echo "    -> Cloning custom postiz-app repository (forcing fresh clone if corrupted)..."
    rm -rf postiz-app 2>/dev/null || true
    git clone https://github.com/infadroidmx/postiz-custom.git postiz-app
    cd postiz-app
else
    echo "    -> Pulling latest code for postiz-app from custom remote..."
    cd postiz-app
    git reset --hard HEAD
    # Attempt down from main normally
    git pull origin main || git pull
fi

echo "==> [7/9] Configuring .env file..."

echo "    -> Detecting Server IP (IPv4)..."
SERVER_IP=$(/usr/bin/curl -4 -s ifconfig.me || wget -qO- ifconfig.me || /usr/bin/wget -qO- api.ipify.org || echo "localhost")
echo "    -> Server IP detected as: $SERVER_IP"

echo "    -> Building .env file with your configured options..."
> .env
echo "DATABASE_URL=\"postgresql://${POSTIZ_DB_USER}:${POSTIZ_DB_PASS}@localhost:5432/postiz-db-local\"" >> .env
echo "REDIS_URL=\"redis://localhost:6379\"" >> .env
echo "JWT_SECRET=\"${POSTIZ_JWT_SECRET}\"" >> .env
echo "FRONTEND_URL=\"http://${SERVER_IP}:4200\"" >> .env
echo "NEXT_PUBLIC_BACKEND_URL=\"http://${SERVER_IP}:3000\"" >> .env
echo "BACKEND_INTERNAL_URL=\"http://localhost:3000\"" >> .env
echo "TEMPORAL_ADDRESS=\"localhost:7233\"" >> .env
echo "NX_ADD_PLUGINS=false" >> .env
echo "IS_GENERAL=\"true\"" >> .env
echo "UPLOAD_DIRECTORY=\"/opt/postiz/uploads/\"" >> .env

# Conditionally append optional configurations
if [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then echo "CLOUDFLARE_ACCOUNT_ID=\"$CLOUDFLARE_ACCOUNT_ID\"" >> .env; fi
if [ -n "$CLOUDFLARE_ACCESS_KEY" ]; then echo "CLOUDFLARE_ACCESS_KEY=\"$CLOUDFLARE_ACCESS_KEY\"" >> .env; fi
if [ -n "$CLOUDFLARE_SECRET_ACCESS_KEY" ]; then echo "CLOUDFLARE_SECRET_ACCESS_KEY=\"$CLOUDFLARE_SECRET_ACCESS_KEY\"" >> .env; fi
if [ -n "$CLOUDFLARE_BUCKETNAME" ]; then echo "CLOUDFLARE_BUCKETNAME=\"$CLOUDFLARE_BUCKETNAME\"" >> .env; fi
if [ -n "$CLOUDFLARE_BUCKET_URL" ]; then echo "CLOUDFLARE_BUCKET_URL=\"$CLOUDFLARE_BUCKET_URL\"" >> .env; fi

if [ -n "$EMAIL_PROVIDER" ]; then echo "EMAIL_PROVIDER=\"$EMAIL_PROVIDER\"" >> .env; fi
if [ -n "$RESEND_API_KEY" ]; then echo "RESEND_API_KEY=\"$RESEND_API_KEY\"" >> .env; fi
if [ -n "$EMAIL_HOST" ]; then echo "EMAIL_HOST=\"$EMAIL_HOST\"" >> .env; fi
if [ -n "$EMAIL_PORT" ]; then echo "EMAIL_PORT=\"$EMAIL_PORT\"" >> .env; fi
if [ -n "$EMAIL_SECURE" ]; then echo "EMAIL_SECURE=\"$EMAIL_SECURE\"" >> .env; fi
if [ -n "$EMAIL_USER" ]; then echo "EMAIL_USER=\"$EMAIL_USER\"" >> .env; fi
if [ -n "$EMAIL_PASS" ]; then echo "EMAIL_PASS=\"$EMAIL_PASS\"" >> .env; fi

if [ -n "$X_API_KEY" ]; then echo "X_API_KEY=\"$X_API_KEY\"" >> .env; fi
if [ -n "$X_API_SECRET" ]; then echo "X_API_SECRET=\"$X_API_SECRET\"" >> .env; fi
if [ -n "$LINKEDIN_CLIENT_ID" ]; then echo "LINKEDIN_CLIENT_ID=\"$LINKEDIN_CLIENT_ID\"" >> .env; fi
if [ -n "$LINKEDIN_CLIENT_SECRET" ]; then echo "LINKEDIN_CLIENT_SECRET=\"$LINKEDIN_CLIENT_SECRET\"" >> .env; fi
if [ -n "$REDDIT_CLIENT_ID" ]; then echo "REDDIT_CLIENT_ID=\"$REDDIT_CLIENT_ID\"" >> .env; fi
if [ -n "$REDDIT_CLIENT_SECRET" ]; then echo "REDDIT_CLIENT_SECRET=\"$REDDIT_CLIENT_SECRET\"" >> .env; fi
if [ -n "$GITHUB_CLIENT_ID" ]; then echo "GITHUB_CLIENT_ID=\"$GITHUB_CLIENT_ID\"" >> .env; fi
if [ -n "$GITHUB_CLIENT_SECRET" ]; then echo "GITHUB_CLIENT_SECRET=\"$GITHUB_CLIENT_SECRET\"" >> .env; fi

if [ -n "$OPENAI_API_KEY" ]; then echo "OPENAI_API_KEY=\"$OPENAI_API_KEY\"" >> .env; fi

mkdir -p /opt/postiz/uploads/

echo "    -> Injecting Server IP into Next.js Config to fix WebSocket DevTools freezing..."
sed -i "s/__DYNAMIC_IP__/${SERVER_IP}/g" apps/frontend/next.config.js 2>/dev/null || true

echo "==> [8/9] Installing npm dependencies and migrating DB..."
echo "    -> Wiping node_modules to guarantee non-corrupted PNPM symlinks for NEXT.js..."
rm -rf node_modules apps/*/node_modules libraries/*/node_modules 2>/dev/null || true

pnpm install

pnpm install
pnpm run prisma-db-push

echo "==> [9/9] Restarting the Development Server..."
echo "    -> Terminating old processes..."
pkill -f "pnpm run dev" || true
pkill -f "next dev" || true
pkill -f "node" || true 

echo "    -> Starting 'pnpm run dev' with expanded Node RAM limits in the background..."
export NODE_OPTIONS="--max-old-space-size=8192"
nohup pnpm run dev > dev.log 2>&1 &

echo "==========================================================================="
echo "✅ Postiz Development Environment is UP and RUNNING!"
echo "---------------------------------------------------------------------------"
echo "Code Location : $DIR/postiz-app"
echo "Frontend URL  : http://${SERVER_IP}:4200"
echo "Backend URL   : http://${SERVER_IP}:3000"
echo "Database User : $POSTIZ_DB_USER"
echo "Live Logs     : tail -f $DIR/postiz-app/dev.log"
echo "==========================================================================="
