#!/bin/bash

echo "🎯 Little's Law Pod Sizing Demo"
echo "==============================="
echo ""
echo "🎓 GOAL: Show how to calculate pod size using Little's Law + JVM/GC impact"
echo "📐 L = λ × W (Queue Length = Throughput × Response Time)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Check dependencies
check_setup() {
    echo -e "${BLUE}🔍 Checking setup...${NC}"
    
    if ! command -v wrk &> /dev/null; then
        echo -e "${RED}❌ wrk not found. Install: brew install wrk${NC}"
        exit 1
    fi
    
    if [[ ! -f "../target/aks-springboot-1.0-SNAPSHOT.jar" ]]; then
        echo -e "${RED}❌ App not built. Run: cd .. && ./mvnw clean package -DskipTests${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Setup OK${NC}"
    echo ""
}

# Start app with specific JVM settings
start_app() {
    local heap=$1
    local gc=$2
    local port=$3
    local name=$4
    
    echo -e "${YELLOW}🚀 Starting $name (port $port)${NC}"
    echo "   Heap: $heap, GC: $gc (explicitly set)"
    
    # Start with GC logging enabled
    java -Xmx$heap -XX:+$gc -Dserver.port=$port \
         -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps \
         -Xloggc:/tmp/gc_$port.log \
         -jar ../target/aks-springboot-1.0-SNAPSHOT.jar > /tmp/app_$port.log 2>&1 &
    
    local pid=$!
    echo $pid > /tmp/app_$port.pid
    
    # Wait for startup
    local count=0
    while [[ $count -lt 15 ]]; do
        if curl -s http://localhost:$port/actuator/health > /dev/null 2>&1; then
            echo -e "${GREEN}   ✅ Started successfully${NC}"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    echo -e "${RED}   ❌ Failed to start${NC}"
    return 1
}

# Run stress test and calculate Little's Law
stress_test() {
    local port=$1
    local name=$2
    local connections=$3
    
    echo -e "${CYAN}🔥 Stress Testing: $name${NC}"
    echo "   Target: http://localhost:$port/cpu-intensive?n=10000"
    echo "   Load: $connections concurrent connections for 20s"
    
    # Run load test
    local output=$(wrk -t4 -c$connections -d20s "http://localhost:$port/cpu-intensive?n=10000" 2>/dev/null)
    
    # Extract metrics
    local throughput=$(echo "$output" | grep "Requests/sec:" | awk '{print $2}')
    local latency=$(echo "$output" | grep "Latency" | awk '{print $2}' | head -1)
    
    # Convert latency to milliseconds
    if [[ $latency == *"ms"* ]]; then
        latency=$(echo $latency | sed 's/ms//')
    elif [[ $latency == *"s"* ]]; then
        latency=$(echo $latency | sed 's/s//')
        latency=$(echo "scale=1; $latency * 1000" | bc)
    elif [[ $latency == *"us"* ]]; then
        latency=$(echo $latency | sed 's/us//')
        latency=$(echo "scale=1; $latency / 1000" | bc)
    fi
    
    # Calculate Little's Law
    local latency_sec=$(echo "scale=4; $latency / 1000" | bc)
    local queue_length=$(echo "scale=1; $throughput * $latency_sec" | bc)
    
    echo -e "${GREEN}📊 Results:${NC}"
    echo "   λ (Throughput): $throughput RPS"
    echo "   W (Response Time): $latency ms"
    echo "   L (Queue Length): $queue_length requests"
    echo -e "   ${BLUE}Little's Law: L = λ × W = $throughput × $latency_sec = $queue_length${NC}"
    echo ""
    
    # Store results for pod sizing calculation
    echo "$throughput,$latency,$queue_length" > "/tmp/results_$port.txt"
    
    # Analyze GC impact after stress test
    analyze_gc_impact "$port" "$name" "20"
}

# Analyze GC impact
analyze_gc_impact() {
    local port=$1
    local name=$2
    local test_duration=$3
    
    echo -e "${BLUE}🔍 GC Impact Analysis: $name${NC}"
    
    if [[ -f "/tmp/gc_$port.log" ]]; then
        # Count GC events during test
        local gc_count=$(grep -c "GC" "/tmp/gc_$port.log" || echo "0")
        
        # Calculate total GC time (simplified)
        local total_gc_time=$(grep "GC" "/tmp/gc_$port.log" | grep -o '[0-9]\+\.[0-9]\+secs' | sed 's/secs//' | awk '{sum += $1} END {printf "%.2f", sum}' || echo "0")
        
        # Calculate GC overhead percentage
        local gc_overhead=$(echo "scale=2; ($total_gc_time / $test_duration) * 100" | bc || echo "0")
        
        echo "   GC Events: $gc_count"
        echo "   Total GC Time: ${total_gc_time}s"
        echo "   GC Overhead: ${gc_overhead}% of test duration"
        echo "   Impact: $(if (( $(echo "$gc_overhead > 5" | bc -l) )); then echo "🔴 HIGH"; elif (( $(echo "$gc_overhead > 2" | bc -l) )); then echo "🟡 MEDIUM"; else echo "🟢 LOW"; fi)"
        echo ""
        
        # Store GC metrics
        echo "$gc_count,$total_gc_time,$gc_overhead" > "/tmp/gc_metrics_$port.txt"
    else
        echo "   ⚠️  No GC log found"
        echo ""
    fi
}

# Calculate pod sizing
calculate_pods() {
    echo -e "${MAGENTA}🎯 POD SIZING CALCULATION${NC}"
    echo "=========================="
    echo ""
    
    # Get best performance results
    local best_throughput=0
    local best_latency=0
    
    if [[ -f "/tmp/results_8082.txt" ]]; then
        IFS=',' read -r best_throughput best_latency _ < "/tmp/results_8082.txt"
    fi
    
    if [[ $best_throughput == 0 ]]; then
        echo "No performance data available"
        return
    fi
    
    echo -e "${BLUE}📈 Single Pod Performance (Optimized JVM):${NC}"
    echo "   Max Throughput: $best_throughput RPS"
    echo "   Response Time: $best_latency ms"
    echo ""
    
    # Calculate for different scenarios
    local scenarios=(
        "500,Production Load"
        "1000,Black Friday"
        "2000,Viral Event"
    )
    
    for scenario in "${scenarios[@]}"; do
        IFS=',' read -r expected_rps name <<< "$scenario"
        
        # Calculate pods needed (with 25% buffer)
        local exact_pods=$(echo "scale=2; $expected_rps / $best_throughput" | bc)
        local safe_pods=$(echo "scale=0; ($expected_rps * 1.25) / $best_throughput + 1" | bc)
        
        # Calculate total system metrics with safe pod count
        local total_capacity=$(echo "$safe_pods * $best_throughput" | bc)
        local latency_sec=$(echo "scale=4; $best_latency / 1000" | bc)
        local total_queue=$(echo "scale=1; $expected_rps * $latency_sec" | bc)
        
        echo -e "${YELLOW}🎯 $name ($expected_rps RPS):${NC}"
        echo "   Exact pods needed: $exact_pods"
        echo "   Safe pods (25% buffer): $safe_pods"
        echo "   Total capacity: $total_capacity RPS"
        echo "   System queue length: $total_queue requests"
        echo "   Cost: $safe_pods × \$100/month = \$$(echo "$safe_pods * 100" | bc)/month"
        echo ""
    done
}

# Stop all apps
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    for port in 8081 8082; do
        if [[ -f "/tmp/app_$port.pid" ]]; then
            local pid=$(cat "/tmp/app_$port.pid")
            kill $pid 2>/dev/null
            rm -f "/tmp/app_$port.pid"
        fi
    done
    rm -f /tmp/results_*.txt /tmp/app_*.log /tmp/gc_*.log /tmp/gc_metrics_*.txt
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Main demo flow
main() {
    check_setup
    
    echo -e "${CYAN}🎬 DEMO: JVM Impact on Pod Sizing${NC}"
    echo ""
    echo "We'll test 2 JVM configurations and show how it affects pod sizing:"
    echo "1. Poor JVM settings (small heap + SerialGC - forced)"
    echo "2. Good JVM settings (large heap + G1GC - JVM default for large heaps)"
    echo ""
    echo "💡 Fun Fact: Modern JVMs automatically select G1GC for heaps ≥ ~1792MB"
    echo "   Our demo forces SerialGC on small heap to show the difference!"
    echo ""
    
    read -p "Press Enter to start..."
    echo ""
    
    # Test 1: Poor JVM configuration
    echo -e "${RED}🔴 TEST 1: Poor JVM Configuration${NC}"
    start_app "256m" "UseSerialGC" "8081" "Poor JVM"
    if [[ $? -eq 0 ]]; then
        stress_test "8081" "Poor JVM" "50"
        analyze_gc_impact "8081" "Poor JVM" "20"
        
        # Show why this is bad
        echo -e "${RED}💡 Impact:${NC}"
        echo "   • Frequent GC pauses increase response time"
        echo "   • Higher W means more requests waiting (higher L)"
        echo "   • Poor user experience under load"
        echo "   • Check GC metrics above for evidence!"
        echo ""
    fi
    
    read -p "Press Enter for optimized JVM test..."
    echo ""
    
    # Test 2: Good JVM configuration  
    echo -e "${GREEN}🟢 TEST 2: Optimized JVM Configuration${NC}"
    start_app "1g" "UseG1GC" "8082" "Optimized JVM"
    if [[ $? -eq 0 ]]; then
        stress_test "8082" "Optimized JVM" "50"
        analyze_gc_impact "8082" "Optimized JVM" "20"
        
        # Show why this is better
        echo -e "${GREEN}💡 Impact:${NC}"
        echo "   • G1GC reduces pause times"
        echo "   • Lower W means fewer requests waiting (lower L)"
        echo "   • Better throughput and user experience"
        echo "   • See GC metrics above for proof!"
        echo ""
    fi
    
    read -p "Press Enter to calculate pod sizing..."
    echo ""
    
    # Calculate optimal pod sizing
    calculate_pods
    
    echo -e "${CYAN}🎓 KEY INSIGHTS:${NC}"
    echo "1. JVM tuning directly affects Little's Law variables"
    echo "2. Better JVM settings = Lower W = Lower L for same λ"
    echo "3. GC overhead directly impacts response time and throughput"
    echo "4. Pod sizing should be based on optimized performance"
    echo "5. Always include buffer capacity for traffic spikes"
    echo "6. Monitor L (queue length) to detect when scaling is needed"
    echo ""
    
    # Compare GC impact between configurations
    echo -e "${CYAN}🔬 GC Impact Comparison:${NC}"
    echo ""
    
    if [[ -f "/tmp/gc_metrics_8081.txt" && -f "/tmp/gc_metrics_8082.txt" ]]; then
        IFS=',' read -r poor_gc_count poor_gc_time poor_gc_overhead < "/tmp/gc_metrics_8081.txt"
        IFS=',' read -r good_gc_count good_gc_time good_gc_overhead < "/tmp/gc_metrics_8082.txt"
        
        echo "   Poor JVM (SerialGC):"
        echo "     • GC Events: $poor_gc_count"
        echo "     • GC Time: ${poor_gc_time}s"
        echo "     • GC Overhead: ${poor_gc_overhead}%"
        echo ""
        echo "   Optimized JVM (G1GC):"
        echo "     • GC Events: $good_gc_count"
        echo "     • GC Time: ${good_gc_time}s"
        echo "     • GC Overhead: ${good_gc_overhead}%"
        echo ""
        
        # Calculate improvement
        local gc_improvement=$(echo "scale=1; $poor_gc_overhead - $good_gc_overhead" | bc)
        echo -e "   ${GREEN}🎯 GC Improvement: ${gc_improvement}% less overhead${NC}"
        echo "   This translates to more CPU time for actual work!"
        echo ""
    fi
    
    cleanup
    
    echo -e "${GREEN}🎉 Demo Complete!${NC}"
    echo ""
    echo -e "${BLUE}Remember: L = λ × W${NC}"
    echo "GC overhead affects both λ and W - optimize it for better pod sizing!"
}

# Run the demo
main
