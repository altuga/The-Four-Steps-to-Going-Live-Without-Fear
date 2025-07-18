#!/bin/bash

# GC Comparison Demo with 4 CPUs
# This script demonstrates how GC selection affects performance even with abundant CPU resources

set -e

echo "🚀 GC Performance Demo with 4 CPUs"
echo "This demonstrates that GC selection matters even with abundant CPU resources!"
echo

# Configuration
MEMORY="1500m"
CPUS="4"
DURATION="30"
OBJECT_SIZE="100"
PORT="8080"

# Array of GC configurations to test
declare -A GC_CONFIGS
GC_CONFIGS["G1GC"]="-XX:+UseG1GC"
GC_CONFIGS["SerialGC"]="-XX:+UseSerialGC" 
GC_CONFIGS["ParallelGC"]="-XX:+UseParallelGC"
GC_CONFIGS["ZGC"]="-XX:+UseZGC -XX:+UnlockExperimentalVMOptions"

# Results storage
RESULTS_DIR="./gc-comparison-results"
mkdir -p "$RESULTS_DIR"

# Function to run test with specific GC
run_gc_test() {
    local gc_name="$1"
    local gc_options="$2"
    local container_name="spring-gc-test-${gc_name,,}"
    
    echo "🧪 Testing $gc_name with 4 CPUs and ${MEMORY} memory"
    echo "   GC Options: $gc_options"
    
    # Stop any existing container
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    
    # Start container with specific GC
    echo "   Starting container..."
    docker run -d \
        --name "$container_name" \
        --cpus="$CPUS" \
        --memory="$MEMORY" \
        -p "${PORT}:8080" \
        -p "9999:9999" \
        -e "JAVA_OPTS=-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9999 -Dcom.sun.management.jmxremote.rmi.port=9999 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.local.only=false -Djava.rmi.server.hostname=127.0.0.1 -Xmx${MEMORY} $gc_options" \
        spring-visualvm:latest > /dev/null
    
    # Wait for startup
    echo "   Waiting for application startup..."
    for i in {1..30}; do
        if curl -s "http://localhost:${PORT}/inspect" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    
    if ! curl -s "http://localhost:${PORT}/inspect" > /dev/null 2>&1; then
        echo "   ❌ Failed to start application with $gc_name"
        return 1
    fi
    
    echo "   ✅ Application started successfully"
    
    # Get initial system info
    echo "   Getting system info..."
    curl -s "http://localhost:${PORT}/inspect" | jq '.' > "$RESULTS_DIR/${gc_name,,}_system_info.json"
    
    # Run memory stress test
    echo "   Running memory stress test for ${DURATION} seconds..."
    local start_time=$(date +%s)
    
    curl -s "http://localhost:${PORT}/memoryStress?durationSeconds=${DURATION}&objectSizeKB=${OBJECT_SIZE}" | jq '.' > "$RESULTS_DIR/${gc_name,,}_memory_stress.json"
    
    local end_time=$(date +%s)
    local actual_duration=$((end_time - start_time))
    
    # Extract key metrics
    local gc_time=$(cat "$RESULTS_DIR/${gc_name,,}_memory_stress.json" | jq -r '.gcStats | to_entries | map(.value.timeMs) | add // 0')
    local gc_count=$(cat "$RESULTS_DIR/${gc_name,,}_memory_stress.json" | jq -r '.gcStats | to_entries | map(.value.collections) | add // 0')
    local total_allocations=$(cat "$RESULTS_DIR/${gc_name,,}_memory_stress.json" | jq -r '.totalAllocations // 0')
    
    echo "   📊 Results for $gc_name:"
    echo "      Duration: ${actual_duration}s"
    echo "      Total GC Time: ${gc_time}ms"
    echo "      GC Collections: $gc_count"
    echo "      Total Allocations: $total_allocations"
    echo "      GC Overhead: $(echo "scale=2; $gc_time / ($actual_duration * 1000) * 100" | bc -l)%"
    echo
    
    # Stop container
    docker stop "$container_name" > /dev/null
    docker rm "$container_name" > /dev/null
    
    # Increment port to avoid conflicts
    PORT=$((PORT + 1))
}

# Main execution
echo "Building Docker image..."
docker build -f Dockerfile.visualvm -t spring-visualvm:latest . > /dev/null

echo
echo "Starting GC comparison tests..."
echo "Each test will run for ${DURATION} seconds with 4 CPUs and ${MEMORY} memory"
echo

# Run tests for each GC
for gc_name in "${!GC_CONFIGS[@]}"; do
    run_gc_test "$gc_name" "${GC_CONFIGS[$gc_name]}"
    sleep 2  # Brief pause between tests
done

# Generate summary report
echo "📈 SUMMARY REPORT"
echo "================="
echo
printf "%-12s %-10s %-15s %-10s %-12s\n" "GC Type" "GC Time" "Collections" "GC%" "Allocations"
printf "%-12s %-10s %-15s %-10s %-12s\n" "--------" "--------" "-----------" "----" "-----------"

for gc_name in "${!GC_CONFIGS[@]}"; do
    if [[ -f "$RESULTS_DIR/${gc_name,,}_memory_stress.json" ]]; then
        local gc_time=$(cat "$RESULTS_DIR/${gc_name,,}_memory_stress.json" | jq -r '.gcStats | to_entries | map(.value.timeMs) | add // 0')
        local gc_count=$(cat "$RESULTS_DIR/${gc_name,,}_memory_stress.json" | jq -r '.gcStats | to_entries | map(.value.collections) | add // 0')
        local allocations=$(cat "$RESULTS_DIR/${gc_name,,}_memory_stress.json" | jq -r '.totalAllocations // 0')
        local gc_overhead=$(echo "scale=1; $gc_time / ($DURATION * 1000) * 100" | bc -l)
        
        printf "%-12s %-10s %-15s %-10s %-12s\n" "$gc_name" "${gc_time}ms" "$gc_count" "${gc_overhead}%" "$allocations"
    fi
done

echo
echo "🎯 KEY FINDINGS:"
echo "   Even with 4 CPUs, GC choice significantly impacts:"
echo "   • Total pause time (GC overhead)"
echo "   • Number of garbage collection events"
echo "   • Application throughput"
echo "   • Memory allocation patterns"
echo
echo "📁 Detailed results saved in: $RESULTS_DIR/"
echo "   Use 'jq .' on the JSON files to see complete metrics"
echo
echo "🔍 To see GC details in real-time, connect VisualVM to port 9999 during tests"
