#!/bin/bash

# CPU Throttling Lesson Demo Script
# Educational demonstration of Docker CPU throttling

echo "🎓 CPU THROTTLING LESSON DEMONSTRATION"
echo "======================================"
echo ""

# Step 1: Setup
echo "📋 STEP 1: Environment Setup"
echo "----------------------------"
echo "1.1 Checking Docker container status..."
if docker ps | grep -q "spring-1cpu"; then
    echo "✅ Container 'spring-1cpu' is running"
    docker ps --filter name=spring-1cpu --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "❌ Container not found. Starting container..."
    docker run -d --name spring-1cpu --cpus=1.0 --memory=1g -p 8080:8080 -p 9998:9998 spring-visualvm
    sleep 5
fi

echo ""
echo "1.2 Container resource limits:"
docker inspect spring-1cpu | jq -r '.[] | "CPU Limit: " + (.HostConfig.CpuQuota / .HostConfig.CpuPeriod | tostring) + " cores"'
docker inspect spring-1cpu | jq -r '.[] | "Memory Limit: " + (.HostConfig.Memory / 1024 / 1024 | tostring) + " MB"'

echo ""
echo "1.3 Testing application endpoint..."
curl -s "http://localhost:8080/" || echo "❌ Application not ready yet, please wait..."

echo ""
echo "📚 STEP 2: Understanding the Problem"
echo "-----------------------------------"
echo "Little's Law in Practice:"
echo "  • Demand: 10 threads × 100% CPU each = 1000% CPU demand"
echo "  • Supply: Docker limit = 100% CPU (1 core)"
echo "  • Result: 900% excess demand = Throttling required"
echo ""

echo "🔬 STEP 3: Monitoring Setup"
echo "---------------------------"
echo "We'll monitor multiple metrics:"
echo "  1. Docker stats (CPU percentage)"
echo "  2. cgroup throttling counters"
echo "  3. Application response times"
echo "  4. JVM performance metrics"
echo ""

read -p "Press Enter to start the demonstration..."

echo ""
echo "🚀 STEP 4: Starting Load Test"
echo "-----------------------------"
echo "Starting CPU throttling monitor in background..."
./local-demo/cpu-throttling-monitor.sh spring-1cpu 120 &
MONITOR_PID=$!

sleep 3

echo ""
echo "Triggering CPU-intensive workload..."
echo "Command: curl 'http://localhost:8080/cpuStress'"
echo ""

# Trigger the load
START_TIME=$(date +%s)
curl -w "\nResponse time: %{time_total}s\n" "http://localhost:8080/cpuStress"
END_TIME=$(date +%s)

echo ""
echo "⏱️  Load test completed in $((END_TIME - START_TIME)) seconds"

echo ""
echo "🔍 STEP 5: Real-time Monitoring"
echo "-------------------------------"
echo "Monitor CPU usage while load is running:"
echo "  Command: docker stats spring-1cpu"
echo ""
echo "Watch for:"
echo "  • CPU% approaching 100%"
echo "  • Memory usage patterns"
echo "  • Container performance impact"
echo ""

# Wait for monitoring to complete
wait $MONITOR_PID

echo ""
echo "📊 STEP 6: Analysis & Learning Points"
echo "------------------------------------"
echo ""
echo "🎯 Key Observations to Discuss:"
echo "1. CPU Utilization Patterns:"
echo "   • Container reaches 100% CPU quickly"
echo "   • Sustained high CPU usage"
echo "   • Throttling events when demand exceeds supply"
echo ""
echo "2. Performance Impact:"
echo "   • Response times increase during throttling"
echo "   • Application becomes less responsive"
echo "   • Resource contention affects all threads"
echo ""
echo "3. Business Impact:"
echo "   • User experience degradation"
echo "   • Reduced throughput"
echo "   • Unpredictable performance"
echo ""

echo "💡 STEP 7: Solutions & Best Practices"
echo "------------------------------------"
echo "1. Proper Resource Sizing:"
echo "   • Monitor actual CPU usage patterns"
echo "   • Size containers based on peak demand + buffer"
echo "   • Use CPU requests vs limits appropriately"
echo ""
echo "2. Application Optimization:"
echo "   • Implement circuit breakers"
echo "   • Use connection pooling"
echo "   • Optimize thread pool sizes"
echo ""
echo "3. Monitoring & Alerting:"
echo "   • Set up CPU throttling alerts"
echo "   • Monitor response time percentiles"
echo "   • Track resource utilization trends"
echo ""

echo "🧪 STEP 8: Interactive Experiments"
echo "----------------------------------"
echo "Try these experiments to see different behaviors:"
echo ""
echo "1. Change CPU limits:"
echo "   docker update --cpus='0.5' spring-1cpu  # More throttling"
echo "   docker update --cpus='2.0' spring-1cpu  # Less throttling"
echo ""
echo "2. Monitor different metrics:"
echo "   docker exec spring-1cpu cat /sys/fs/cgroup/cpu.stat"
echo "   docker exec spring-1cpu cat /proc/loadavg"
echo ""
echo "3. Test with VisualVM:"
echo "   • Connect to localhost:9998"
echo "   • Monitor CPU usage, GC, threads"
echo "   • Observe throttling impact on JVM metrics"
echo ""

echo "✅ LESSON COMPLETE!"
echo "==================="
echo "Files created:"
echo "  • cpu-throttling-monitor.sh - Monitoring script"
echo "  • throttling-demo-*.log - Detailed metrics log"
echo ""
echo "Next steps:"
echo "  1. Analyze the log file for patterns"
echo "  2. Experiment with different CPU limits"
echo "  3. Compare with unlimited CPU containers"
echo "  4. Measure impact on application SLAs"
