#!/bin/bash

echo "🔍 Spring Boot App GC Selection Test"
echo "===================================="
echo ""
echo "Java Version: $(java -version 2>&1 | head -1)"
echo "Testing which GC is actually used by our Spring Boot app with different heap sizes..."
echo ""

# Check if app is built
if [[ ! -f "../target/aks-springboot-1.0-SNAPSHOT.jar" ]]; then
    echo "❌ App not built. Run: cd .. && ./mvnw clean package -DskipTests"
    exit 1
fi

# Function to test actual GC selection with Spring Boot app
test_springboot_gc() {
    local heap_size=$1
    local port=$((8090 + RANDOM % 100))  # Random port to avoid conflicts
    
    echo -n "Heap: $heap_size -> "
    
    # Start Spring Boot app with specific heap size and GC logging enabled
    java -Xmx$heap_size -Dserver.port=$port \
         -XX:+PrintCommandLineFlags \
         -XX:+PrintGCDetails \
         -XX:+PrintGC \
         -XX:+UseStringDeduplication 2>/dev/null || true \
         -jar ../target/aks-springboot-1.0-SNAPSHOT.jar > /tmp/gc_test_$port.log 2>&1 &
    
    local pid=$!
    
    # Wait for app to start and capture GC info
    sleep 6
    
    # Create a small load to trigger GC
    curl -s http://localhost:$port/actuator/health >/dev/null 2>&1 || true
    curl -s http://localhost:$port/prime/1000 >/dev/null 2>&1 || true
    
    sleep 2
    
    # Check which GC is actually being used from multiple sources
    local gc_info=""
    local gc_name=""
    
    # Method 1: Check PrintCommandLineFlags output for explicit GC flags
    gc_info=$(grep -o 'Use[A-Za-z]*GC' /tmp/gc_test_$port.log 2>/dev/null | head -1)
    
    # Method 2: Look for "Using" GC messages in the logs
    if [[ -z "$gc_info" ]]; then
        if grep -q "Using G1" /tmp/gc_test_$port.log 2>/dev/null; then
            gc_name="G1GC"
        elif grep -q "Using Parallel" /tmp/gc_test_$port.log 2>/dev/null; then
            gc_name="ParallelGC"
        elif grep -q "Using Serial" /tmp/gc_test_$port.log 2>/dev/null; then
            gc_name="SerialGC"
        elif grep -q "Using Z" /tmp/gc_test_$port.log 2>/dev/null; then
            gc_name="ZGC"
        fi
    fi
    
    # Method 3: Parse the PrintCommandLineFlags for -XX:+Use*GC flags
    if [[ -z "$gc_info" && -z "$gc_name" ]]; then
        if grep -q "\-XX:+UseG1GC" /tmp/gc_test_$port.log 2>/dev/null; then
            gc_name="G1GC"
        elif grep -q "\-XX:+UseParallelGC" /tmp/gc_test_$port.log 2>/dev/null; then
            gc_name="ParallelGC"
        elif grep -q "\-XX:+UseSerialGC" /tmp/gc_test_$port.log 2>/dev/null; then
            gc_name="SerialGC"
        elif grep -q "\-XX:+UseZGC" /tmp/gc_test_$port.log 2>/dev/null; then
            gc_name="ZGC"
        fi
    fi
    
    # Stop the app
    kill $pid 2>/dev/null
    wait $pid 2>/dev/null
    
    # Clean up log
    rm -f /tmp/gc_test_$port.log
    
    # Display result based on what we found
    local final_gc="${gc_info}${gc_name}"
    
    if [[ $final_gc == *"G1"* ]]; then
        echo "🟢 G1GC (low-latency, concurrent)"
    elif [[ $final_gc == *"Serial"* ]]; then
        echo "🔴 SerialGC (single-threaded, simple)"
    elif [[ $final_gc == *"Parallel"* ]]; then
        echo "🟡 ParallelGC (multi-threaded, throughput)"
    elif [[ $final_gc == *"ZGC"* ]]; then
        echo "🚀 ZGC (ultra-low latency)"
    else
        echo "🔵 Unable to detect GC (likely Parallel or G1)"
    fi
    
    sleep 1  # Brief pause between tests
}

echo "📊 Testing Spring Boot app with different heap sizes:"
echo "(Each test starts the app briefly to check actual GC selection)"
echo ""

# Test various heap sizes around the threshold
test_springboot_gc "256m"
test_springboot_gc "512m"
test_springboot_gc "1024m"
test_springboot_gc "1536m"
test_springboot_gc "1791m"
test_springboot_gc "1792m"  # The critical threshold!
test_springboot_gc "2048m"
test_springboot_gc "4096m"

echo ""
echo "🎯 Key Findings:"
echo "   • JVM automatically selects GC based on heap size"
echo "   • Threshold varies by JVM version and available memory"
echo "   • Modern JVMs prefer G1GC for larger heaps"
echo ""
echo "💡 This explains why our pod sizing demo shows:"
echo "   • Small heap (256m) = Different GC = Different performance"
echo "   • Large heap (1g+) = Different GC = Different performance"
echo ""
echo "📚 To see all JVM flags: java -XX:+PrintCommandLineFlags -version"
