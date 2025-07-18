#!/bin/bash

# Parameterized Docker runner for Spring Boot app
# Usage: ./run-spring-docker.sh [CPUS] [MEMORY] [HEAP_PERCENT] [GC_TYPE] [EXTRA_JVM_OPTS]
#    OR: ./run-spring-docker.sh [CPUS] [MEMORY] [GC_TYPE] [EXTRA_JVM_OPTS]
# 
# Examples: 
#   ./run-spring-docker.sh 2 1500m 80 g1 "-XX:+FlightRecorder"  # With heap %
#   ./run-spring-docker.sh 2 1500m g1 "-XX:+FlightRecorder"     # Skip heap %
#   ./run-spring-docker.sh 4 1500m g1                           # Just GC type

cpus=${1:-1}
memory=${2:-'512m'}
heappercent=${3}
gc_type=${4:-'default'}
extra_jvm_opts=${5:-''}

# Smart parameter parsing - if 3rd param looks like a GC type, shift parameters
if [[ "$heappercent" =~ ^(g1|parallel|serial|shenandoah|zgc|default|none)$ ]]; then
    # 3rd parameter is actually GC type, not heap percentage
    gc_type=$heappercent
    heappercent=""
    extra_jvm_opts=${4:-''}
fi

container_name="spring-five-steps"
image_name="spring-five-steps:latest"

echo "=== The Five Steps to Going Live Without Fear - Docker Runner ==="
echo "CPUs: $cpus"
echo "Memory: $memory"
echo "Heap Percent: ${heappercent:-'JVM Default'}"
echo "GC Type: $gc_type"
echo "Extra JVM Options: ${extra_jvm_opts:-'None'}"
echo

# Set heap percentage flags if specified
if [ -n "$heappercent" ]; then
    heap_flags="-XX:InitialRAMPercentage=$heappercent -XX:MinRAMPercentage=$heappercent -XX:MaxRAMPercentage=$heappercent"
else
    heap_flags=""
fi

# Set GC flags based on gc_type parameter
case $gc_type in
    shenandoah)
        gc_flags="-XX:+UseShenandoahGC"
        gc_description="Shenandoah GC (low-latency, concurrent collector)"
        ;;
    g1)
        gc_flags="-XX:+UseG1GC"
        gc_description="G1 GC (low-latency, good for large heaps)"
        ;;
    parallel)
        gc_flags="-XX:+UseParallelGC"
        gc_description="Parallel GC (high-throughput, good for batch processing)"
        ;;
    serial)
        gc_flags="-XX:+UseSerialGC"
        gc_description="Serial GC (single-threaded, good for small heaps)"
        ;;
    zgc)
        gc_flags="-XX:+UseZGC"
        gc_description="Z GC (ultra-low latency, good for very large heaps)"
        ;;
    default)
        gc_flags=""
        gc_description="JVM Default GC (usually G1 for Java 21)"
        ;;
    none)
        gc_flags=""
        gc_description="No explicit GC settings"
        ;;
    *)
        echo "Invalid GC type. Use: default, none, shenandoah, g1, parallel, serial, zgc"
        exit 1
        ;;
esac

echo "GC Description: $gc_description"
echo

# Stop and remove existing container if running
echo "Stopping existing container..."
docker stop $container_name 2>/dev/null
docker rm $container_name 2>/dev/null

# Build the Docker image if it doesn't exist
if ! docker images | grep -q "$image_name"; then
    echo "Building Docker image..."
    docker build -f Dockerfile.visualvm -t $image_name .
    if [ $? -ne 0 ]; then
        echo "Failed to build Docker image"
        exit 1
    fi
fi

# Combine all JVM options
jvm_opts=""
if [ -n "$heap_flags" ]; then
    jvm_opts="$jvm_opts $heap_flags"
fi
if [ -n "$gc_flags" ]; then
    jvm_opts="$jvm_opts $gc_flags"
fi
if [ -n "$extra_jvm_opts" ]; then
    jvm_opts="$jvm_opts $extra_jvm_opts"
fi

echo "Starting Spring Boot application with:"
echo "  Docker CPU limit: $cpus"
echo "  Docker Memory limit: $memory"
echo "  JVM Options: $jvm_opts"
echo

# Run the container with specified resource limits and JVM options via environment
echo "Running container..."
docker run -d \
    --name $container_name \
    --cpus=$cpus \
    --memory=$memory \
    -p 8080:8080 \
    -p 9999:9999 \
    -e "JAVA_OPTS=$jvm_opts" \
    $image_name \
    sh -c "java \
        -Dcom.sun.management.jmxremote \
        -Dcom.sun.management.jmxremote.port=9999 \
        -Dcom.sun.management.jmxremote.rmi.port=9999 \
        -Dcom.sun.management.jmxremote.authenticate=false \
        -Dcom.sun.management.jmxremote.ssl=false \
        -Dcom.sun.management.jmxremote.local.only=false \
        -Djava.rmi.server.hostname=127.0.0.1 \
        -Dcom.sun.management.jmxremote.registry.ssl=false \
        $jvm_opts \
        -jar app.jar"

# Wait a moment for startup
sleep 3

# Check if container is running
if docker ps | grep -q $container_name; then
    echo
    echo "✅ Container started successfully!"
    echo "📊 Application URL: http://localhost:8080"
    echo "🔍 VisualVM JMX: localhost:9999"
    echo "📈 Actuator Health: http://localhost:8080/actuator/health"
    echo "🧮 Prime Factor Endpoint: http://localhost:8080/primeFactor/1000000"
    echo "💥 CPU Stress Endpoint: http://localhost:8080/cpuStress/10000"
    echo
    echo "📋 Useful monitoring commands:"
    echo "  docker stats $container_name"
    echo "  docker logs $container_name"
    echo "  docker exec -it $container_name jcmd 1 VM.classloader_stats"
    echo "  docker exec -it $container_name jcmd 1 GC.run_finalization"
    echo
    echo "🛑 To stop: docker stop $container_name"
else
    echo "❌ Failed to start container"
    docker logs $container_name
    exit 1
fi
