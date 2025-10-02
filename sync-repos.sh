#!/bin/bash

echo "🔄 Синхронизация Helm репозиториев с PostgreSQL..."

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo "📋 Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo "⚠️  No .env file found. Copy .env.template to .env and configure it."
    exit 1
fi

# Check if asset-syncer binary exists
if [ ! -f "cmd/asset-syncer/asset-syncer" ]; then
    echo "📦 Building asset-syncer..."
    cd cmd/asset-syncer
    /usr/local/go/bin/go build -o asset-syncer .
    cd ../..
fi

# Database connection string (asset-syncer использует другой формат)
DB_URL="$POSTGRES_HOST:$POSTGRES_PORT"
DB_NAME="$POSTGRES_DB"
DB_USER="$POSTGRES_USER"
DB_PASS="$POSTGRES_PASSWORD"

echo "✅ Using Database: $POSTGRES_USER@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"
echo "✅ Using KUBECONFIG: $KUBECONFIG"

cd cmd/asset-syncer

# Set PostgreSQL password environment variable
export PGPASSWORD="$DB_PASS"

# Sync Stable repository (надежный и стабильный)
echo "🔄 Syncing Stable repository..."
./asset-syncer sync --database-url="$DB_URL" --database-name="$DB_NAME" --database-user="$DB_USER" --namespace=default stable https://charts.helm.sh/stable helm

# Sync Ingress-nginx repository (популярный и рабочий)
echo "🔄 Syncing Ingress-nginx repository..."
./asset-syncer sync --database-url="$DB_URL" --database-name="$DB_NAME" --database-user="$DB_USER" --namespace=default ingress-nginx https://kubernetes.github.io/ingress-nginx helm

echo "✅ Repository synchronization completed!"
echo "📊 Checking PostgreSQL data..."

cd ../..
psql -d kubeapps -c "SELECT COUNT(*) as total_charts FROM charts;"
psql -d kubeapps -c "SELECT COUNT(*) as total_repos FROM repos;"

echo "🎉 Done! Refresh your Kubeapps UI to see the catalog."