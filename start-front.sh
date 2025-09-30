#!/bin/bash

echo "🎨 Starting dashboard frontend..."

# Check if node_modules exists
if [ ! -d "dashboard/node_modules" ]; then
    echo "📦 Installing dependencies..."
    cd dashboard
    yarn install
    cd ..
fi

# Start frontend dashboard
cd dashboard
yarn start