#!/bin/bash

echo "🔧 Starting kubeapps-apis backend server..."

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo "📋 Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo "⚠️  No .env file found. Copy .env.template to .env and configure it."
    echo "cp .env.template .env"
    exit 1
fi

# Check if kubeapps-apis binary exists
if [ ! -f "cmd/kubeapps-apis/kubeapps-apis" ]; then
    echo "📦 Building kubeapps-apis..."
    cd cmd/kubeapps-apis
    go build -o kubeapps-apis .
    cd ../..
fi

# Check KUBECONFIG
if [ -z "$KUBECONFIG" ]; then
    echo "❌ KUBECONFIG not set in .env file"
    exit 1
fi

echo "✅ Using KUBECONFIG: $KUBECONFIG"
echo "✅ Using PostgreSQL: $POSTGRES_USER@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"

# Start backend API server
cd cmd/kubeapps-apis
export POD_NAMESPACE=${POD_NAMESPACE:-default}

# Asset Syncer variables
export ASSET_SYNCER_DB_URL="$POSTGRES_HOST:$POSTGRES_PORT"
export ASSET_SYNCER_DB_NAME="$POSTGRES_DB"
export ASSET_SYNCER_DB_USERNAME="$POSTGRES_USER"
export ASSET_SYNCER_DB_USERPASSWORD="$POSTGRES_PASSWORD"

# Helm plugin variables
export DB_URL="$POSTGRES_HOST:$POSTGRES_PORT"
export DB_NAME="$POSTGRES_DB"
export DB_USERNAME="$POSTGRES_USER"
export DB_PASSWORD="$POSTGRES_PASSWORD"
export PGPASSWORD="$POSTGRES_PASSWORD"

# Global namespace for Helm repositories
export HELM_GLOBAL_NAMESPACE="default"
export GLOBAL_PACKAGING_NAMESPACE="default"
KUBECONFIG="$KUBECONFIG" ./kubeapps-apis serve --port=50051 --unsafe-local-dev-kubeconfig --global-repos-namespace=default