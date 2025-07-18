#!/bin/bash

# CPU Throttling Monitoring Script for Educational Demo
# This script monitors Docker container CPU throttling metrics

CONTAINER_NAME=${1:-"spring-1cpu"}
DURATION=${2:-300}  # 5 minutes default

echo "🎯 CPU Throttling Monitoring Demo"
echo "=================================="
echo "Container: $CONTAINER_NAME"
echo "Duration: $DURATION seconds"
echo "Time: $(date)"
echo ""

# Check if container exists
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container '$CONTAINER_NAME' not found!"
    echo "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 1
fi

# Get container limits
echo "📊 Container Resource Limits:"
CPUS=$(docker inspect $CONTAINER_NAME | jq -r '.[0].HostConfig.CpuQuota / .[0].HostConfig.CpuPeriod' 2>/dev/null || echo "unlimited")
MEMORY=$(docker inspect $CONTAINER_NAME | jq -r '.[0].HostConfig.Memory' 2>/dev/null | sed 's/0/unlimited/')
echo "  - CPU Limit: $CPUS CPUs"
echo "  - Memory Limit: $MEMORY bytes"
echo ""

# Create log file with timestamp
LOG_FILE="throttling-demo-$(date +%Y%m%d-%H%M%S).log"
echo "📝 Logging to: $LOG_FILE"
echo ""

# Function to get throttling stats
get_throttling_stats() {
    local container=$1
    
    # Get CPU stats from cgroup
    local cpu_stats=$(docker exec $container cat /sys/fs/cgroup/cpu.stat 2>/dev/null || echo "throttled_usec 0")
    local throttled_usec=$(echo "$cpu_stats" | grep throttled_usec | awk '{print $2}')
    
    # Get Docker stats
    local docker_stats=$(docker stats $container --no-stream --format "{{.CPUPerc}},{{.MemUsage}}")
    local cpu_perc=$(echo "$docker_stats" | cut -d',' -f1 | sed 's/%//')
    local mem_usage=$(echo "$docker_stats" | cut -d',' -f2)
    
    echo "$throttled_usec,$cpu_perc,$mem_usage"
}

# Header for CSV log
echo "timestamp,throttled_usec,cpu_percent,memory_usage,throttling_events" > $LOG_FILE

echo "🔍 Starting monitoring (Press Ctrl+C to stop)..."
echo "Time        | CPU%  | Throttled μs | Memory    | Events | Status"
echo "------------|-------|--------------|-----------|--------|--------"

prev_throttled=0
throttling_events=0
start_time=$(date +%s)

while [ $(($(date +%s) - start_time)) -lt $DURATION ]; do
    current_time=$(date '+%H:%M:%S')
    stats=$(get_throttling_stats $CONTAINER_NAME)
    
    if [ "$stats" != "0,," ]; then
        throttled_usec=$(echo "$stats" | cut -d',' -f1)
        cpu_perc=$(echo "$stats" | cut -d',' -f2)
        mem_usage=$(echo "$stats" | cut -d',' -f3)
        
        # Calculate new throttling events
        if [ "$throttled_usec" -gt "$prev_throttled" ]; then
            throttling_events=$((throttling_events + 1))
            status="⚠️  THROTTLING"
        else
            status="✅ Normal"
        fi
        
        # Format output
        printf "%s | %5.1f | %12s | %9s | %6d | %s\n" \
            "$current_time" "$cpu_perc" "$throttled_usec" "$mem_usage" "$throttling_events" "$status"
        
        # Log to CSV
        echo "$(date -Iseconds),$throttled_usec,$cpu_perc,$mem_usage,$throttling_events" >> $LOG_FILE
        
        prev_throttled=$throttled_usec
    fi
    
    sleep 2
done

echo ""
echo "📈 Monitoring Complete!"
echo "Total throttling events detected: $throttling_events"
echo "Log file: $LOG_FILE"
echo ""
echo "💡 Analysis Tips:"
echo "1. High CPU% with increasing throttled_usec = CPU throttling occurring"
echo "2. Frequent throttling events = container needs more CPU resources"
echo "3. Use 'docker stats' to see real-time resource usage"
echo "4. Check application response times during throttling periods"
