#!/bin/bash

echo "🧹 Cleanup Demo Environment"
echo "=========================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping all Java processes...${NC}"

# Stop any running Spring Boot applications
pkill -f "aks-springboot" 2>/dev/null

# Clean up temp files
rm -f /tmp/app_*.pid /tmp/app_*.log /tmp/results_*.txt

# Wait a moment for processes to stop
sleep 2

echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""
echo "All demo processes stopped and temp files removed."

# Check ports
echo "🔍 Checking if ports are free..."
for port in 8081 8082 8083; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "⚠️  Port $port still in use"
    else
        echo "✅ Port $port is free"
    fi
done

echo ""
echo "🎉 Cleanup complete!"
echo "💡 You can now run a fresh demonstration with:"
echo "   ./littles-law-demo.sh"
