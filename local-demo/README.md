# 🎯 Little's Law Pod Sizing Demo

## 🚀 Quick Start

```bash
# 1. Build the app
cd .. && ./mvnw clean package

# 2. Run the demo
./pod-sizing-demo.sh
```

## 🎓 What You'll See

**The demo proves 2 key points:**

### 1. **JVM Tuning Impact on Little's Law**
- **Poor JVM** (256MB heap + SerialGC): High response time → High queue length
- **Good JVM** (1GB heap + G1GC): Low response time → Low queue length  
- **Evidence**: Real stress test data + GC metrics showing 2-5x improvement
- **GC Impact**: Measures GC overhead percentage and its effect on performance

### 2. **Calculate Pod Count Using Little's Law**
- Measure single pod performance: λ (throughput) and W (response time)
- Calculate L (queue length): L = λ × W
- Determine pods needed: Expected Load ÷ Pod Capacity + Buffer
- **Example**: 1000 RPS target ÷ 75 RPS per pod = 14 pods + 25% buffer = 18 pods

## 📊 Demo Output Example

```
🔴 Poor JVM: λ=30 RPS, W=800ms → L=24 requests → GC=8% overhead
🟢 Good JVM: λ=75 RPS, W=200ms → L=15 requests → GC=2% overhead

Pod Sizing for 1000 RPS:
- Poor JVM: Need 42 pods (1000÷30×1.25)
- Good JVM: Need 17 pods (1000÷75×1.25)
- Cost Savings: 60% fewer pods with JVM tuning!
- GC Impact: 6% less CPU overhead = better performance
```

## 🎯 Key Takeaway

**Little's Law (L = λ × W) + JVM/GC tuning = Optimal pod sizing**

Use this demo to show stakeholders the **business impact** of performance optimization!