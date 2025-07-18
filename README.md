# Little's Law Demonstration - Local JVM Benchmark

[![Java CI with Maven](https://github.com/brunoborges/aks-jvm-benchmark/actions/workflows/maven.yml/badge.svg)](https://github.com/brunoborges/aks-jvm-benchmark/actions/workflows/maven.yml)

This project demonstrates **Little's Law** (L = λ × W) through horizontal scaling using local JVM instances. Perfect for learning queueing theory and performance concepts without cloud complexity or costs.

## 🎯 Little's Law Demonstration

**Little's Law**: `L = λ × W`
- **L**: Average number of requests in the system
- **λ**: Arrival rate (throughput - requests/second)  
- **W**: Average response time (seconds)

## 🚀 Quick Start

### Prerequisites
- Java 17+
- Maven (or use included `./mvnw`)
- `wrk` load testing tool: `brew install wrk`

### Run the Demonstration
```bash
# Build the application
./mvnw clean package

# Run the complete Little's Law demonstration
cd local-demo
./littles-law-demo.sh
```

## 🏠 Local Demonstration Features

### ✅ **What You'll See**
1. **Phase 1**: Single "pod" performance limits
2. **Phase 2**: Horizontal scaling benefits  
3. **Phase 3**: Optimal throughput with multiple instances

### ✅ **Benefits**
- **Free** - No cloud costs
- **Fast** - Immediate setup
- **Educational** - Clear demonstration of concepts
- **Repeatable** - Run as many times as needed

## 📁 Project Structure

```
├── local-demo/          # All demonstration scripts
│   ├── littles-law-demo.sh      # Complete automated demo
│   ├── simple-littles-law.sh    # Quick demo
│   ├── monitor.sh               # Real-time dashboard
│   └── cleanup.sh               # Stop all processes
├── src/                 # Java Spring Boot application
├── pom.xml             # Maven configuration
└── README.md           # This file
```


## Generate HdrHistogram chart
See: http://hdrhistogram.github.io/HdrHistogram/plotFiles.html


### Demo script

First we show difference between GCs and Heap config with the same resource limits (1 CPU, 1 GB RAM).

Then we use the Load Balancer and fire up wrk against them.

#### Comparing different JVM settings

Start the benchmark with this script:

```bash
wrk -t10 -c50 -d5m -R3000 -L http://internal-sampleapp-all.default.svc.cluster.local/json
```

Wait with Prime Factor:

```bash
wrk -t10 -c50 -d5m -R3000 -L  http://internal-sampleapp-all.default.svc.cluster.local/waitWithPrimeFactor?duration=50\&number=927398173993974
```



#### Comparing different resource configurations

Because the k8s Load Balancer only round robin against pods, we must use Nginx for a two-tier load balancing approach.

Delete the gc-related pods, and deploy the `redistribution` pods, followed by `nginx` pod.



Start the benchmark with this script:

```bash
wrk -t10 -c50 -d5m -R3000 -L http://internal-nginx.default.svc.cluster.local/json
```

Wait with Prime Factor:

```bash
wrk -t10 -c50 -d5m -R3000 -L  http://internal-nginx.default.svc.cluster.local/waitWithPrimeFactor?duration=50\&number=927398173993974
```

