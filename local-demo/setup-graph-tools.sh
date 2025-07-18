#!/bin/bash

# Setup script for CPU throttling graph capture tools

echo "🔧 Setting up CPU Throttling Graph Capture Tools"
echo "================================================"

# Check operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macOS"
    PACKAGE_MANAGER="brew"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="Linux"
    if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    else
        PACKAGE_MANAGER="unknown"
    fi
else
    PLATFORM="Unknown"
    PACKAGE_MANAGER="unknown"
fi

echo "Platform: $PLATFORM"
echo "Package Manager: $PACKAGE_MANAGER"
echo ""

# Install gnuplot for basic graphing
echo "📦 Installing gnuplot..."
case $PACKAGE_MANAGER in
    "brew")
        if ! command -v gnuplot >/dev/null 2>&1; then
            brew install gnuplot
        else
            echo "✅ gnuplot already installed"
        fi
        ;;
    "apt")
        if ! command -v gnuplot >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y gnuplot
        else
            echo "✅ gnuplot already installed"
        fi
        ;;
    "yum")
        if ! command -v gnuplot >/dev/null 2>&1; then
            sudo yum install -y gnuplot
        else
            echo "✅ gnuplot already installed"
        fi
        ;;
    *)
        echo "⚠️  Please install gnuplot manually for your system"
        ;;
esac

# Check Python and install dependencies
echo ""
echo "🐍 Setting up Python dependencies..."

if command -v python3 >/dev/null 2>&1; then
    echo "✅ Python3 found: $(python3 --version)"
    
    # Install pip if not available
    if ! python3 -m pip --version >/dev/null 2>&1; then
        echo "Installing pip..."
        curl https://bootstrap.pypa.io/get-pip.py | python3
    fi
    
    # Install required packages
    echo "Installing matplotlib and pandas..."
    python3 -m pip install matplotlib pandas --user
    
    echo "✅ Python dependencies installed"
else
    echo "⚠️  Python3 not found. Please install Python 3.6+ for advanced graphing"
fi

# Check Docker
echo ""
echo "🐳 Checking Docker..."
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker found: $(docker --version)"
    
    # Check if Docker daemon is running
    if docker ps >/dev/null 2>&1; then
        echo "✅ Docker daemon is running"
    else
        echo "⚠️  Docker daemon not running. Please start Docker"
    fi
else
    echo "❌ Docker not found. Please install Docker"
    exit 1
fi

# Check for jq (for JSON parsing)
echo ""
echo "🔍 Checking jq..."
if command -v jq >/dev/null 2>&1; then
    echo "✅ jq found"
else
    echo "Installing jq..."
    case $PACKAGE_MANAGER in
        "brew")
            brew install jq
            ;;
        "apt")
            sudo apt-get install -y jq
            ;;
        "yum")
            sudo yum install -y jq
            ;;
        *)
            echo "⚠️  Please install jq manually"
            ;;
    esac
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "🎯 Available CPU Throttling Tools:"
echo "=================================="
echo ""
echo "1. Basic Graph Capture (bash + gnuplot):"
echo "   ./capture-throttling-graph.sh [container] [duration]"
echo ""
echo "2. Advanced Visualization (Python):"
echo "   python3 cpu-throttling-visualizer.py --container spring-1cpu --duration 120"
echo ""
echo "3. Real-time Monitoring:"
echo "   ./cpu-throttling-monitor.sh [container] [duration]"
echo ""
echo "4. Complete Lesson:"
echo "   ./throttling-lesson.sh"
echo ""
echo "📝 Usage Examples:"
echo "=================="
echo ""
echo "# Capture 2-minute graph while running load test"
echo "./capture-throttling-graph.sh spring-1cpu 120"
echo ""
echo "# Advanced visualization with Python"
echo "python3 cpu-throttling-visualizer.py -c spring-1cpu -d 180"
echo ""
echo "# Start container and trigger load"
echo "docker run -d --name spring-1cpu --cpus=1.0 --memory=1g -p 8080:8080 spring-visualvm"
echo "curl 'http://localhost:8080/cpuStress'"
echo ""
echo "🎓 Ready to demonstrate CPU throttling!"
