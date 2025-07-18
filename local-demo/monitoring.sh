#!/bin/bash
# filepath: /Users/altugbilginaltintas/IdeaProjects/aks-jvm-benchmark/monitor-millicores.sh

CONTAINER_NAME=${1:-"spring-1cpu"}

echo "🔍 Monitoring CPU usage in millicores for: $CONTAINER_NAME"
echo "=================================================="

while true; do
    # Get CPU percentage from docker stats
    CPU_PERCENT=$(docker stats --no-stream --format "{{.CPUPerc}}" $CONTAINER_NAME | sed 's/%//')
    
    # Calculate millicores based on container CPU limit
    CONTAINER_CPUS=$(docker inspect $CONTAINER_NAME | jq -r '.[0].HostConfig.CpuQuota / .[0].HostConfig.CpuPeriod')
    
    if [ "$CONTAINER_CPUS" == "null" ] || [ "$CONTAINER_CPUS" == "-1" ]; then
        CONTAINER_CPUS=1.0
    fi
    
    # Convert to millicores
    MILLICORES=$(echo "$CPU_PERCENT * $CONTAINER_CPUS * 10" | bc -l | cut -d. -f1)
    
    # Get app metrics
    APP_CPU=$(curl -s http://localhost:8080/inspect 2>/dev/null | jq -r '.["osMXBean.getCpuLoad"] // 0' | awk '{printf "%.2f", $1 * 100}')
    
    echo "$(date '+%H:%M:%S') - Docker: ${MILLICORES}m cores (${CPU_PERCENT}%) | App: ${APP_CPU}%"
    
    sleep 2
done