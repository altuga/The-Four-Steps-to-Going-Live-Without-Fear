#!/bin/bash

# Aggressive CPU Throttling Demonstration
# This script creates extreme CPU demand to force visible throttling (CPU% -> 0)

echo "🎯 AGGRESSIVE CPU THROTTLING DEMONSTRATION"
echo "=========================================="
echo "Goal: Force CPU% to drop to 0% during throttling events"
echo ""

CONTAINER_NAME=${1:-"spring-1cpu"}
DURATION=${2:-180}  # 3 minutes

# Check container exists
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container '$CONTAINER_NAME' not found!"
    echo "Creating a container with VERY restrictive limits..."
    
    # Create container with much more restrictive limits
    docker run -d --name spring-throttle-demo \
        --cpus=0.25 \
        --memory=512m \
        -p 8082:8080 \
        spring-visualvm
    
    CONTAINER_NAME="spring-throttle-demo"
    sleep 3
fi

echo "📊 Container Configuration:"
echo "=========================="
docker inspect $CONTAINER_NAME | jq -r '.[] | 
    "CPU Quota: " + (.HostConfig.CpuQuota | tostring) + " microseconds",
    "CPU Period: " + (.HostConfig.CpuPeriod | tostring) + " microseconds", 
    "CPU Cores: " + ((.HostConfig.CpuQuota / .HostConfig.CpuPeriod) | tostring),
    "Memory: " + (.HostConfig.Memory / 1024 / 1024 | tostring) + " MB"'

echo ""
echo "🔬 Expected Behavior:"
echo "===================="
echo "• With multiple threads demanding CPU"
echo "• Container will hit quota limit quickly"
echo "• Kernel will PAUSE the container (throttling)"
echo "• CPU% should drop to 0% during pause periods"
echo "• This creates the characteristic throttling pattern"
echo ""

# Create data file
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATA_FILE="aggressive-throttling-$TIMESTAMP.csv"
echo "timestamp,seconds,cpu_percent,throttled_usec,nr_throttled,throttled_periods" > $DATA_FILE

echo "🚀 Starting aggressive monitoring..."
echo "Time    | CPU%  | Throttled μs | Events | Status"
echo "--------|-------|--------------|--------|--------"

start_time=$(date +%s)
prev_throttled=0
throttle_events=0

# Start the monitoring loop
while [ $(($(date +%s) - start_time)) -lt $DURATION ]; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Get detailed stats
    cpu_percent=$(docker stats $CONTAINER_NAME --no-stream --format "{{.CPUPerc}}" | sed 's/%//' || echo "0")
    
    # Get throttling stats from cgroup
    if docker exec $CONTAINER_NAME test -f /sys/fs/cgroup/cpu.stat 2>/dev/null; then
        throttling_stats=$(docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.stat 2>/dev/null)
        throttled_usec=$(echo "$throttling_stats" | grep throttled_usec | awk '{print $2}' || echo "0")
        nr_throttled=$(echo "$throttling_stats" | grep nr_throttled | awk '{print $2}' || echo "0")
        throttled_periods=$(echo "$throttling_stats" | grep throttled_periods | awk '{print $2}' || echo "0")
    else
        throttled_usec="0"
        nr_throttled="0" 
        throttled_periods="0"
    fi
    
    # Detect throttling events
    if [ "$throttled_usec" -gt "$prev_throttled" ]; then
        throttle_events=$((throttle_events + 1))
        if [ "${cpu_percent%.*}" -lt 10 ]; then
            status="🚨 THROTTLED!"
        else
            status="⚠️  Limiting"
        fi
    else
        if [ "${cpu_percent%.*}" -gt 90 ]; then
            status="🔥 High Load"
        else
            status="✅ Normal"
        fi
    fi
    
    # Display current status
    printf "%7ds | %5.1f | %12s | %6d | %s\n" \
        "$elapsed" "$cpu_percent" "$throttled_usec" "$throttle_events" "$status"
    
    # Log to CSV
    echo "$(date -Iseconds),$elapsed,$cpu_percent,$throttled_usec,$nr_throttled,$throttled_periods" >> $DATA_FILE
    
    prev_throttled=$throttled_usec
    sleep 1
done

echo ""
echo "📈 Analysis Complete!"
echo "===================="

# Generate analysis
echo ""
echo "🔍 THROTTLING ANALYSIS:"

# Find periods where CPU dropped to near 0 during high throttling
awk -F',' 'NR>1 {
    if($3 < 5 && prev_throttled > 0 && $4 > prev_throttled) {
        zero_cpu_events++
        total_zero_time += 1
    }
    if($3 > 90) high_cpu_periods++
    if($4 > max_throttled) max_throttled = $4
    prev_throttled = $4
    total_samples++
}
END {
    print "📊 Throttling Evidence:"
    printf "  • CPU near 0%% during throttling: %d events\n", zero_cpu_events
    printf "  • Total time with CPU < 5%%: %d seconds\n", total_zero_time  
    printf "  • High CPU periods (>90%%): %d\n", high_cpu_periods
    printf "  • Maximum throttled time: %d μs\n", max_throttled
    
    if(zero_cpu_events > 0) {
        print ""
        print "✅ SUCCESS: Clear throttling evidence captured!"
        print "   CPU dropped to ~0% during throttling events"
    } else {
        print ""
        print "⚠️  Limited throttling observed"
        print "   Try with more restrictive CPU limits or more load"
    }
}' $DATA_FILE

echo ""
echo "💡 To see more dramatic throttling:"
echo "=================================="
echo "1. Reduce CPU limit further:"
echo "   docker update --cpus='0.1' $CONTAINER_NAME"
echo ""
echo "2. Generate more concurrent load:"
echo "   for i in {1..5}; do curl \"http://localhost:8082/cpuStress\" & done"
echo ""
echo "3. Use stress testing tools:"
echo "   docker exec $CONTAINER_NAME stress --cpu 8 --timeout 30s"
echo ""
echo "📁 Data saved to: $DATA_FILE"
