# CPU Throttling Monitoring Commands - Quick Reference

## 1. Basic Monitoring Commands

# Real-time container stats
docker stats spring-1cpu

# CPU throttling from cgroup
docker exec spring-1cpu cat /sys/fs/cgroup/cpu.stat

# System load inside container  
docker exec spring-1cpu cat /proc/loadavg

# Memory pressure
docker exec spring-1cpu cat /proc/meminfo | grep -E "(MemTotal|MemAvailable|MemFree)"

## 2. Demonstration Commands

# Trigger CPU load (10 threads, 10 seconds)
curl "http://localhost:8080/cpuStress"

# Check application health
curl "http://localhost:8080/inspect"

# Get system information
curl "http://localhost:8080/inspect" | jq '.["osMXBean.getCpuLoad"]'

## 3. Advanced Monitoring

# Monitor throttling events in real-time
watch -n 1 'docker exec spring-1cpu cat /sys/fs/cgroup/cpu.stat | grep throttled'

# Combined monitoring
./local-demo/cpu-throttling-monitor.sh spring-1cpu 300

# Complete lesson demonstration
./local-demo/throttling-lesson.sh

## 4. Experiment with Different Limits

# Reduce CPU limit (more throttling)
docker update --cpus='0.5' spring-1cpu

# Increase CPU limit (less throttling)
docker update --cpus='2.0' spring-1cpu

# Reset to original
docker update --cpus='1.0' spring-1cpu

## 5. Comparison Testing

# Create unlimited CPU container
docker run -d --name spring-unlimited --memory=1g -p 8081:8080 spring-visualvm

# Compare performance
time curl "http://localhost:8080/cpuStress"   # Limited
time curl "http://localhost:8081/cpuStress"   # Unlimited

## 6. VisualVM Connection

# Connect to: localhost:9998
# Monitor: CPU, Memory, Threads, GC
# Observe: Impact of throttling on JVM metrics

## 7. Log Analysis

# View throttling events
grep "THROTTLING" throttling-demo-*.log

# Count throttling events
grep -c "THROTTLING" throttling-demo-*.log

# CPU usage over time
awk -F',' '{print $1,$3}' throttling-demo-*.log | tail -20
