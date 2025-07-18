#!/bin/bash

cpus=${1:-1}
memory=${2:-'128m'}
heappercent=${3}
gc_type=${4:-'default'}  # New parameter: default, shenandoah, g1, parallel, serial, zgc

if [ -n "$heappercent" ]; then
    heappercent="-XX:InitialRAMPercentage=$heappercent -XX:MinRAMPercentage=$heappercent -XX:MaxRAMPercentage=$heappercent"
fi

# Set GC flags based on gc_type parameter
case $gc_type in
    shenandoah)
        gc_flags="-XX:+UseShenandoahGC"
        ;;
    g1)
        gc_flags="-XX:+UseG1GC"
        ;;
    parallel)
        gc_flags="-XX:+UseParallelGC"
        ;;
    serial)
        gc_flags="-XX:+UseSerialGC"
        ;;
    zgc)
        gc_flags="-XX:+UseZGC"
        ;;
    default)
        gc_flags=""
        ;;
    *)
        echo "Invalid GC type. Use: default, shenandoah, g1, parallel, serial, zgc"
        exit 1
        ;;
esac

echo "Starting evaluation with $cpus CPUs, $memory memory, and GC: $gc_type"

image='eclipse-temurin:24'  # Java 24

# Compile Sample.java for clean run
docker run --rm -v "$(pwd)":/usr/src/myapp -w /usr/src/myapp $image javac Sample.java

# Function to convert bytes to MB
convert_to_mb() {
    local bytes=$1
    local mb=$((bytes / 1024 / 1024))
    echo "${mb}MB"
}

# Test Heap Size Configuration
echo "# Heap Size Configuration:"
heap_output=$(docker run --memory=$memory --cpus=$cpus -v `pwd`:/app $image 2>/dev/null \
    java -XX:+AlwaysPreTouch $heappercent $gc_flags -XX:+PrintFlagsFinal -cp /app Sample | grep -E 'InitialHeapSize|MaxHeapSize|MinHeapSize' | head -3)

echo "$heap_output" | while read line; do
    if [[ $line =~ InitialHeapSize.*=\ *([0-9]+) ]]; then
        size=${BASH_REMATCH[1]}
        echo "  Initial Heap Size: $(convert_to_mb $size)"
    elif [[ $line =~ MaxHeapSize.*=\ *([0-9]+) ]]; then
        size=${BASH_REMATCH[1]}
        echo "  Maximum Heap Size: $(convert_to_mb $size)"
    elif [[ $line =~ MinHeapSize.*=\ *([0-9]+) ]]; then
        size=${BASH_REMATCH[1]}
        echo "  Minimum Heap Size: $(convert_to_mb $size)"
    fi
done

# Test Garbage Collector
echo "# Active Garbage Collector:"
gc_output=$(docker run --memory=$memory --cpus=$cpus -v `pwd`:/app $image 2>/dev/null \
    java $gc_flags -XX:+PrintFlagsFinal -cp /app Sample | grep -E 'UseSerial|UseG1|UseParallel|UseZGC|UseShenandoah' | grep 'true')

if [[ $gc_output =~ UseSerialGC.*true ]]; then
    echo "  Serial GC (single-threaded, good for small heaps)"
elif [[ $gc_output =~ UseG1GC.*true ]]; then
    echo "  G1 GC (low-latency, good for large heaps)"
elif [[ $gc_output =~ UseParallelGC.*true ]]; then
    echo "  Parallel GC (high-throughput, good for batch processing)"
elif [[ $gc_output =~ UseZGC.*true ]]; then
    echo "  Z GC (ultra-low latency, good for very large heaps)"
elif [[ $gc_output =~ UseShenandoahGC.*true ]]; then
    echo "  Shenandoah GC (low-latency, concurrent collector)"
else
    echo "  Unknown or default GC"
fi

# MetaSpace Configuration
echo "# Metaspace Configuration:"
metaspace_output=$(docker run --memory=$memory --cpus=$cpus -v `pwd`:/app $image 2>/dev/null \
    java $gc_flags -XX:+PrintFlagsFinal -cp /app Sample | grep 'MetaspaceSize.*=' | grep -v 'Max' | head -1)

if [[ $metaspace_output =~ MetaspaceSize.*=\ *([0-9]+) ]]; then
    size=${BASH_REMATCH[1]}
    echo "  Metaspace Size: $(convert_to_mb $size)"
fi