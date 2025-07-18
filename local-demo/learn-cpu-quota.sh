#!/bin/bash

# Docker CPU Quota and Period Learning Script
# Educational tool to understand Docker CPU throttling mechanisms

CONTAINER_NAME=${1:-"spring-1cpu"}

echo "🎓 DOCKER CPU QUOTA & PERIOD LEARNING"
echo "====================================="
echo ""

# Check if container exists
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container '$CONTAINER_NAME' not found!"
    echo "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 1
fi

echo "📋 Container: $CONTAINER_NAME"
echo ""

echo "🔍 STEP 1: Docker Inspect - Host Configuration"
echo "=============================================="
echo "Docker stores CPU limits in the container configuration:"
echo ""

# Get CPU configuration from docker inspect
docker inspect $CONTAINER_NAME | jq -r '
.[0].HostConfig | 
"CpuQuota: " + (.CpuQuota | tostring) + " microseconds",
"CpuPeriod: " + (.CpuPeriod | tostring) + " microseconds",
"CPU Limit: " + (if .CpuQuota > 0 then (.CpuQuota / .CpuPeriod | tostring) + " cores" else "unlimited" end),
"NanoCpus: " + (.NanoCpus | tostring) + " nanocores"
'

echo ""
echo "💡 Understanding the Numbers:"
echo "  • CpuPeriod: Time window for CPU allocation (usually 100,000 μs = 100ms)"
echo "  • CpuQuota: Maximum CPU time allowed in that period"
echo "  • CPU Limit = CpuQuota / CpuPeriod"
echo "  • Example: 100,000 quota / 100,000 period = 1.0 CPU core"

echo ""
echo "🔍 STEP 2: Inside Container - cgroup Files"
echo "=========================================="
echo "Inside the container, Linux cgroups control CPU access:"
echo ""

# Check cgroup version
echo "Detecting cgroup version..."
if docker exec $CONTAINER_NAME test -f /sys/fs/cgroup/cpu.max 2>/dev/null; then
    echo "✅ cgroup v2 detected"
    CGROUP_VERSION="v2"
else
    echo "✅ cgroup v1 detected"
    CGROUP_VERSION="v1"
fi

echo ""
echo "📁 CPU Control Files:"

if [ "$CGROUP_VERSION" = "v2" ]; then
    echo ""
    echo "=== cgroup v2 files ==="
    echo "1. CPU limits:"
    docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo "   Not available"
    
    echo ""
    echo "2. CPU statistics:"
    docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.stat 2>/dev/null | head -5
    
else
    echo ""
    echo "=== cgroup v1 files ==="
    echo "1. CPU period (microseconds):"
    docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null || echo "   Not available"
    
    echo ""
    echo "2. CPU quota (microseconds):"
    docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null || echo "   Not available"
    
    echo ""
    echo "3. CPU statistics:"
    docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu/cpu.stat 2>/dev/null || echo "   Not available"
fi

echo ""
echo "🔍 STEP 3: Real-time Throttling Monitoring"
echo "=========================================="
echo "Monitor live throttling events:"
echo ""

# Function to monitor throttling
monitor_throttling() {
    local duration=${1:-30}
    echo "Monitoring for $duration seconds..."
    echo "Time    | CPU%  | Throttled μs | Periods | Status"
    echo "--------|-------|--------------|---------|--------"
    
    local start_time=$(date +%s)
    local prev_throttled=0
    
    while [ $(($(date +%s) - start_time)) -lt $duration ]; do
        local current_time=$(date '+%H:%M:%S')
        
        # Get CPU percentage
        local cpu_percent=$(docker stats $CONTAINER_NAME --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
        
        # Get throttling stats based on cgroup version
        if [ "$CGROUP_VERSION" = "v2" ]; then
            local stats=$(docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.stat 2>/dev/null)
            local throttled_usec=$(echo "$stats" | grep throttled_usec | awk '{print $2}' || echo "0")
            local nr_periods=$(echo "$stats" | grep nr_periods | awk '{print $2}' || echo "0")
        else
            local throttled_usec=$(docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu/cpu.stat 2>/dev/null | grep throttled_time | awk '{print $2}' || echo "0")
            local nr_periods=$(docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu/cpu.stat 2>/dev/null | grep nr_periods | awk '{print $2}' || echo "0")
        fi
        
        # Determine status
        local status="Normal"
        if [ "$throttled_usec" -gt "$prev_throttled" ]; then
            status="🚨 THROTTLING"
        fi
        
        printf "%s | %5.1f | %12s | %7s | %s\n" \
            "$current_time" "$cpu_percent" "$throttled_usec" "$nr_periods" "$status"
        
        prev_throttled=$throttled_usec
        sleep 2
    done
}

# Start monitoring in background for 30 seconds
echo "Starting 30-second monitoring..."
echo "💡 In another terminal, run: curl 'http://localhost:8080/cpuStress'"
echo ""

monitor_throttling 30

echo ""
echo "🎓 STEP 4: Learning Summary"
echo "=========================="
echo ""
echo "📚 Key Concepts:"
echo "1. CFS (Completely Fair Scheduler):"
echo "   • Linux kernel CPU scheduler"
echo "   • Uses periods and quotas for throttling"
echo "   • Default period: 100ms (100,000 microseconds)"
echo ""
echo "2. Docker CPU Limits:"
echo "   • --cpus=1.0 means 1 full CPU core"
echo "   • Implemented via cgroup quotas"
echo "   • Enforced by the Linux kernel"
echo ""
echo "3. Throttling Detection:"
echo "   • throttled_usec increases when CPU is limited"
echo "   • nr_periods shows total scheduling periods"
echo "   • throttled_periods shows how many were limited"
echo ""
echo "🔬 Advanced Learning Commands:"
echo "============================="
echo ""
echo "1. See all cgroup CPU files:"
if [ "$CGROUP_VERSION" = "v2" ]; then
    echo "   docker exec $CONTAINER_NAME ls -la /sys/fs/cgroup/ | grep cpu"
else
    echo "   docker exec $CONTAINER_NAME ls -la /sys/fs/cgroup/cpu/"
fi
echo ""
echo "2. Monitor throttling in real-time:"
echo "   watch -n 1 'docker exec $CONTAINER_NAME cat /sys/fs/cgroup/cpu.stat'"
echo ""
echo "3. Check Docker resource constraints:"
echo "   docker inspect $CONTAINER_NAME | jq '.[0].HostConfig'"
echo ""
echo "4. Compare with unlimited container:"
echo "   docker run -d --name unlimited --memory=1g spring-visualvm"
echo "   docker inspect unlimited | jq '.[0].HostConfig.CpuQuota'"
echo ""
echo "✅ You now understand Docker CPU quota and period mechanisms!"
