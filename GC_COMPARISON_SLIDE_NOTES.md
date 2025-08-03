# GC Comparison Results - Slide Notes
## "The Five Steps to Going Live Without Fear"

### Overview Slide: "Choosing the Right Garbage Collector"

**Opening Statement:**
"Performance isn't just about picking the 'fastest' garbage collector. It's about choosing the right tool for your specific workload and understanding the trade-offs."

---

## Slide 1: Benchmark Setup & Methodology

### Test Configuration
- **Application**: Spring Boot 21 on eclipse-temurin:21-jdk
- **Container Resources**: 4 CPUs, 5GB Memory
- **Heap Configuration**: Default 25% (~1.25GB heap)
- **Load Test**: 10,000 requests at 100 req/sec using JMeter
- **Endpoint**: `/memoryStress` - realistic web app memory allocation patterns

### Why This Matters
"We're testing real-world scenarios - not synthetic benchmarks. This endpoint simulates typical web application memory patterns: JSON processing, temporary objects, caching, and data structures."

**Key Point**: "This is what your production application actually does - process requests, create temporary objects, and manage memory."

---

## Slide 2: The Results - Throughput Analysis

```
Garbage Collector    | Throughput  | Avg Response Time
---------------------|-------------|------------------
Parallel GC          | 266 req/sec | 373ms
G1GC (Default)       | 263 req/sec | 377ms  
ZGC                  | 191 req/sec | 520ms
Serial GC            | 160 req/sec | 621ms
Shenandoah           | 137 req/sec | 726ms
```

### Speaker Notes:
**"Notice the surprising result!"**
- Parallel GC and G1GC are virtually identical in throughput (266 vs 263 req/sec)
- Only 4ms difference in average response time
- ZGC trades 25% throughput for consistency
- Shenandoah struggles with allocation-heavy workloads

**Key Insight**: "For many applications, the choice between Parallel and G1 isn't about raw performance - it's about predictability."

---

## Slide 3: Latency Distribution - The Real Story

```
GC Type      | 90th %ile | 95th %ile | 99th %ile
-------------|-----------|-----------|----------
G1GC         | 527ms     | 586ms     | 705ms
Parallel     | 790ms     | 959ms     | 1378ms
ZGC          | 845ms     | 960ms     | 1232ms
Serial       | 905ms     | 1002ms    | 1214ms
Shenandoah   | 1195ms    | 1432ms    | 2012ms
```

### Speaker Notes:
**"This is where the magic happens - tail latency!"**

**G1GC Wins the User Experience Battle:**
- "G1GC has the most consistent performance across percentiles"
- "Notice how Parallel GC's 99th percentile jumps to 1378ms - that's nearly 2x worse than G1"
- "This demonstrates the stop-the-world pause impact on user experience"

**The Little's Law Connection:**
- "Higher throughput doesn't always mean better user experience"
- "G1GC provides the best balance of throughput AND predictability"

---

## Slide 4: Understanding the Trade-offs

### Parallel GC - "The Batch Processing Champion"
- ✅ **Best raw throughput** (266 req/sec)
- ✅ **Good average response time** (373ms)
- ❌ **Poor tail latency** (1378ms at 99th percentile)
- **Use Case**: Batch processing, ETL jobs, non-interactive workloads

### G1GC - "The Balanced Choice"
- ✅ **Excellent throughput** (263 req/sec - only 1% less than Parallel)
- ✅ **Best tail latency** (705ms at 99th percentile)
- ✅ **Consistent user experience**
- **Use Case**: Web applications, microservices, most production workloads

### ZGC - "The Consistency King"
- ✅ **Predictable performance** (consistent across percentiles)
- ✅ **Good for large heaps** (8GB+)
- ❌ **Lower throughput** (191 req/sec - 28% less)
- **Use Case**: Large memory applications, strict SLA requirements

---

## Slide 5: The Little's Law Paradox Explained

### The Classic Misconception
"Why does Parallel GC have higher throughput but worse response times?"

### The Answer: Stop-the-World Pauses
**Parallel GC Pattern:**
```
[fast][fast][fast][PAUSE 800ms][fast][fast][PAUSE 800ms]
↳ High average throughput, but users experience occasional long waits
```

**G1GC Pattern:**
```
[medium][medium][medium][pause 200ms][medium][medium]
↳ Slightly lower throughput, but consistent user experience
```

### Speaker Notes:
"Little's Law still applies, but GC pauses create non-steady-state conditions. During a stop-the-world pause, requests queue up, creating high latency spikes even though overall throughput is high."

---

## Slide 6: Production Recommendations

### Step 1: Know Your Workload
- **Interactive applications** → G1GC
- **Batch processing** → Parallel GC
- **Large heaps (8GB+)** → ZGC
- **Strict latency SLAs** → ZGC or G1GC with tuning

### Step 2: Measure, Don't Guess
- **Use realistic load testing**
- **Monitor tail latencies, not just averages**
- **Test with your actual data patterns**

### Step 3: The Default is Good
- **Java 21 defaults to G1GC for good reason**
- **G1GC provides the best balance for most workloads**
- **Only change if you have specific requirements**

---

## Slide 7: Key Takeaways

### 1. Performance ≠ Just Throughput
"263 req/sec with 705ms P99 beats 266 req/sec with 1378ms P99"

### 2. Understand Your Users
"Your users care about consistent response times, not theoretical maximum throughput"

### 3. Test with Real Workloads
"Synthetic benchmarks lie. Test with patterns that match your production traffic"

### 4. The Right Tool for the Job
"There's no 'best' garbage collector - only the best collector for YOUR application"

---

## Slide 8: Going Live Checklist

### ✅ Garbage Collector Selection
- [ ] Profiled application memory patterns
- [ ] Load tested with realistic traffic
- [ ] Measured tail latencies (P95, P99)
- [ ] Chose GC based on workload characteristics

### ✅ The Five Steps Connection
1. **Understand** your memory allocation patterns
2. **Measure** performance under realistic load
3. **Choose** the right GC for your workload
4. **Monitor** tail latencies in production
5. **Iterate** based on real production data

---

## Closing Notes

### The Meta-Lesson
"This isn't just about garbage collectors. It's about making informed technical decisions based on data, understanding trade-offs, and optimizing for what actually matters to your users."

### Call to Action
"Don't just accept defaults - understand them. Don't just optimize for benchmarks - optimize for user experience. And most importantly, measure everything in production."

### Final Quote
"The best garbage collector is the one that helps your users accomplish their goals with the least friction. Sometimes that's the fastest one. Sometimes it's the most predictable one. But it's always the one you chose deliberately."

---

## Technical Appendix (Backup Slides)

### Container Configuration Used
```bash
./run-spring-docker.sh 4 5000m [gc_type]
# Where gc_type: g1, parallel, serial, zgc, shenandoah
```

### JMeter Test Plan
- Thread Group: 100 users
- Ramp-up: 10 seconds  
- Duration: 100 seconds
- Total Requests: 10,000
- Target: http://localhost:8080/memoryStress

### Memory Allocation Pattern
- JSON-like request/response objects
- Temporary string processing
- Collection operations (Lists, Maps)
- Simulated caching (survivor objects)
- Realistic array processing

This pattern represents typical Spring Boot web application memory usage.
