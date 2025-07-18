#!/bin/bash

# Comprehensive CPU Throttling Monitor
# Usage: ./throttling-monitor.sh [container-name]

CONTAINER_NAME=${1:-spring-app}
INTERVAL=${2:-5}

echo "=== CPU Throttling Monitor for $CONTAINER_NAME ==="
echo "Sampling every $INTERVAL seconds. Press Ctrl+C to stop."
echo

# Function to get throttling stats
get_throttling_stats() {
    docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep -E "(nr_periods|nr_throttled|throttled_usec)"
}

# Function to get CPU quota info
get_cpu_quota() {
    docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.max 2>/dev/null
}

# Function to get docker stats
get_docker_stats() {
    docker stats $CONTAINER_NAME --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" | tail -n +2
}

# Initialize previous values
prev_periods=0
prev_throttled=0
prev_throttled_time=0

echo "Time                CPU%    Memory          Quota/Period    Periods  Throttled  Rate%    Throttled_Time"
echo "==================  ======  ==============  ==============  =======  =========  =====    =============="

while true; do
    timestamp=$(date '+%H:%M:%S')
    
    # Get current stats
    cpu_stats=$(get_throttling_stats)
    quota_info=$(get_cpu_quota)
    docker_stats=$(get_docker_stats)
    
    if [ -n "$cpu_stats" ]; then
        # Parse throttling stats
        periods=$(echo "$cpu_stats" | grep nr_periods | awk '{print $2}')
        throttled=$(echo "$cpu_stats" | grep nr_throttled | awk '{print $2}')
        throttled_time=$(echo "$cpu_stats" | grep throttled_usec | awk '{print $2}')
        
        # Calculate rates
        if [ $prev_periods -gt 0 ]; then
            period_delta=$((periods - prev_periods))
            throttled_delta=$((throttled - prev_throttled))
            throttled_time_delta=$((throttled_time - prev_throttled_time))
            
            if [ $period_delta -gt 0 ]; then
                throttle_rate=$(echo "scale=1; $throttled_delta * 100 / $period_delta" | bc -l 2>/dev/null || echo "0")
            else
                throttle_rate="0.0"
            fi
            
            throttled_time_ms=$(echo "scale=1; $throttled_time_delta / 1000" | bc -l 2>/dev/null || echo "0")
        else
            throttle_rate="N/A"
            throttled_time_ms="N/A"
        fi
        
        # Overall throttling rate
        if [ $periods -gt 0 ]; then
            overall_rate=$(echo "scale=1; $throttled * 100 / $periods" | bc -l 2>/dev/null || echo "0")
        else
            overall_rate="0.0"
        fi
        
        # Format quota info
        quota_display=$(echo $quota_info | tr ' ' '/')
        
        # Parse docker stats
        cpu_percent=$(echo "$docker_stats" | awk '{print $1}')
        memory_usage=$(echo "$docker_stats" | awk '{print $2}')
        
        printf "%-18s  %-6s  %-14s  %-14s  %-7s  %-9s  %-5s    %-12s\n" \
            "$timestamp" "$cpu_percent" "$memory_usage" "$quota_display" \
            "$periods" "$throttled" "$overall_rate%" "$throttled_time_ms ms"
        
        # Update previous values
        prev_periods=$periods
        prev_throttled=$throttled
        prev_throttled_time=$throttled_time
    else
        echo "$timestamp  ERROR: Cannot read cgroup stats"
    fi
    
    sleep $INTERVAL
done
