#!/bin/bash

echo "=== The Five Steps to Going Live Without Fear - Usage Examples ==="
echo

# Stop any existing container
docker stop spring-five-steps 2>/dev/null
docker rm spring-five-steps 2>/dev/null

echo "🧪 Example 1: Low resource setup (0.5 CPU, 256M RAM, Serial GC)"
./run-spring-docker.sh 0.5 256m 70 serial
echo "Press Enter to continue to next example..."
read

echo "🧪 Example 2: Medium setup (1 CPU, 512M RAM, G1GC)"
./run-spring-docker.sh 1 512m 75 g1
echo "Press Enter to continue to next example..."
read

echo "🧪 Example 3: High performance setup (2 CPU, 1500M RAM, no explicit GC)"
./run-spring-docker.sh 2 1500m 80 none
echo "Press Enter to continue to next example..."
read

echo "🧪 Example 4: Ultra high performance (4 CPU, 2G RAM, ZGC + Flight Recorder)"
./run-spring-docker.sh 4 2g 85 zgc "-XX:+FlightRecorder -XX:StartFlightRecording=duration=60s,filename=/tmp/flight.jfr"
echo "Container is running!"

echo
echo "📊 Monitor with: docker stats spring-five-steps"
echo "🔍 Test endpoints:"
echo "  curl http://localhost:8080/inspect"
echo "  curl http://localhost:8080/primeFactor/1000000"
echo "  curl http://localhost:8080/cpuStress/5000"
echo
echo "🛑 Stop with: docker stop spring-five-steps"
