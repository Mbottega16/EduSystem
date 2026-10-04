#!/usr/bin/env bash
# Quick launcher for Limezu Sprite Hub & Studio
cd "$(dirname "$0")"
echo "🚀 Starting Limezu Sprite Hub & Studio..."
python3 server.py &
sleep 1
open http://localhost:5050
echo "✨ Dashboard launched at http://localhost:5050"
