#!/bin/bash

echo "🧹 Cleaning up for LOCAL-ONLY Little's Law demo"
echo "==============================================="

# Log files
echo "Removing log files..."
rm -f applicationinsights.log

# Old test directories
echo "Removing old test directories..."
rm -rf test-ergonomics/
rm -rf wrktools/

# Old config files
echo "Removing old config files..."
rm -f AZ_CONFIG
rm -f .gitmodules

# ALL Azure-related files and directories
echo "Removing ALL Azure-related files..."
rm -rf azure-demo/
rm -rf cloud/
rm -rf containers/
rm -rf kubernetes/

# Redundant scripts (functionality moved to local-demo)
echo "Removing redundant scripts..."
rm -f aks-get-credentials.sh
rm -f azure-monitor.sh
rm -f cleanup.sh
rm -f local-benchmark.sh
rm -f jfr.sh

# Add Azure Application Insights config file removal
echo "Removing Azure Application Insights config..."
rm -f src/main/resources/applicationinsights.json

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📁 Remaining structure (LOCAL-ONLY):"
tree -I 'target|.git|.mvn|node_modules' -L 2 || ls -la

echo ""
echo "💾 Space saved:"
du -sh . | cut -f1
echo ""
echo "🎯 The project is now LOCAL-ONLY and focused on Little's Law demonstration!"
echo ""
echo "🚀 Ready to run:"
echo "   cd local-demo"
echo "   ./littles-law-demo.sh"
