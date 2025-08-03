package jug.istanbul.springboot;

import static java.lang.Runtime.getRuntime;

import java.lang.management.ManagementFactory;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class RESTController {

    @GetMapping("/")
    public String helloWorld() {
        return "Hello World";
    }

    @GetMapping("/primeFactor")
    public PrimeFactor findFactor(BigInteger number, Boolean logging) {
        if (number == null) {
            number = BigInteger.valueOf(100L);
        }
        var factorization = new Factorization(Boolean.TRUE.equals(logging));
        var start = Instant.now();
        var factors = factorization.factors(number).stream().map(n -> n.toString()).collect(Collectors.joining(" * "));
        var stop = Instant.now();
        var duration = Duration.between(start, stop);
        var durationInBD = BigDecimal.valueOf(duration.toMillis()).divide(BigDecimal.valueOf(1000));
        return new PrimeFactor(number, factors, durationInBD);
    }

    @GetMapping("/waitWithPrimeFactor")
    public String networkWaitWithPrime(Integer duration, BigInteger number) {
        var primeFactor = findFactor(number, false);
        StringBuilder sb = new StringBuilder();
        sb.append(networkWait(duration));
        sb.append("\n");
        sb.append("Found factors for " + number + ": " + primeFactor);
        return sb.toString();
    }

    @GetMapping("/wait")
    public String networkWait(Integer duration) {
        var random = ThreadLocalRandom.current();
        var randomWait = random.nextInt(2, 50);
        var totalWait = duration + randomWait;
        try {
            Thread.sleep(duration + randomWait);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        return "Waited " + totalWait + "ms (random wait: " + randomWait + "ms)";
    }

    @GetMapping("/inspect")
    public Map<String, Object> inspect() throws ClassNotFoundException {
        var map = new TreeMap<String, Object>();
        var runtime = getRuntime();

        // Memory Management Beans
        var memoryBean = ManagementFactory.getMemoryMXBean();
        var runtimeBean = ManagementFactory.getRuntimeMXBean();

        // Current GC
        var gcIdentifier = new IdentifyCurrentGC();
        map.put("Running GC", gcIdentifier.identifyGC().name());

        var podIP = System.getenv("MY_POD_IP");
        map.put("podIP", podIP);

        // CPUs and Memory
        map.put("availableProcessors", Integer.toString(runtime.availableProcessors()));
        map.put("maxMemory (MB)", Long.toString(runtime.maxMemory() / 1024 / 1024));
        map.put("totalMemory (MB)", Long.toString(runtime.totalMemory() / 1024 / 1024));
        map.put("freeMemory (MB)", Long.toString(runtime.freeMemory() / 1024 / 1024));
        map.put("usedMemory (MB)", Long.toString((runtime.totalMemory() - runtime.freeMemory()) / 1024 / 1024));

        // Heap Memory Details
        var heapMemory = memoryBean.getHeapMemoryUsage();
        var nonHeapMemory = memoryBean.getNonHeapMemoryUsage();

        map.put("heap.used (MB)", formatBytes(heapMemory.getUsed()));
        map.put("heap.committed (MB)", formatBytes(heapMemory.getCommitted()));
        map.put("heap.max (MB)", formatBytes(heapMemory.getMax()));
        map.put("heap.init (MB)", formatBytes(heapMemory.getInit()));

        // Calculate heap usage percentage
        if (heapMemory.getMax() > 0) {
            double heapUsagePercent = (double) heapMemory.getUsed() / heapMemory.getMax() * 100;
            map.put("heap.usagePercent", String.format("%.2f%%", heapUsagePercent));
        } else {
            map.put("heap.usagePercent", "Unknown");
        }

        map.put("nonHeap.used (MB)", formatBytes(nonHeapMemory.getUsed()));
        map.put("nonHeap.committed (MB)", formatBytes(nonHeapMemory.getCommitted()));
        map.put("nonHeap.max (MB)", formatBytes(nonHeapMemory.getMax()));

        // JVM Arguments and RAM Percentage Settings
        var jvmArgs = runtimeBean.getInputArguments();

        String initialRAMPercentage = extractJVMArg(jvmArgs, "InitialRAMPercentage");
        String minRAMPercentage = extractJVMArg(jvmArgs, "MinRAMPercentage");
        String maxRAMPercentage = extractJVMArg(jvmArgs, "MaxRAMPercentage");

        map.put("InitialRAMPercentage", initialRAMPercentage != null ? initialRAMPercentage + "%" : "JVM Default");
        map.put("MinRAMPercentage", minRAMPercentage != null ? minRAMPercentage + "%" : "JVM Default");
        map.put("MaxRAMPercentage", maxRAMPercentage != null ? maxRAMPercentage + "%" : "JVM Default");

        // Container Memory Information
        try {
            // Try to read container memory limit (cgroup v1)
            var memoryLimitPath = java.nio.file.Paths.get("/sys/fs/cgroup/memory/memory.limit_in_bytes");
            if (java.nio.file.Files.exists(memoryLimitPath)) {
                long containerMemoryLimit = Long.parseLong(java.nio.file.Files.readString(memoryLimitPath).trim());
                if (containerMemoryLimit < Long.MAX_VALUE) {
                    map.put("container.memoryLimit (MB)", formatBytes(containerMemoryLimit));
                    if (heapMemory.getMax() > 0) {
                        double heapVsContainerPercent = (double) heapMemory.getMax() / containerMemoryLimit * 100;
                        map.put("heap.vsContainerPercent", String.format("%.2f%%", heapVsContainerPercent));
                    }
                }
            }

            // Try cgroup v2
            var memoryMaxPath = java.nio.file.Paths.get("/sys/fs/cgroup/memory.max");
            if (java.nio.file.Files.exists(memoryMaxPath)) {
                String memoryMaxStr = java.nio.file.Files.readString(memoryMaxPath).trim();
                if (!"max".equals(memoryMaxStr)) {
                    long containerMemoryLimit = Long.parseLong(memoryMaxStr);
                    map.put("container.memoryLimit (MB)", formatBytes(containerMemoryLimit));
                    if (heapMemory.getMax() > 0) {
                        double heapVsContainerPercent = (double) heapMemory.getMax() / containerMemoryLimit * 100;
                        map.put("heap.vsContainerPercent", String.format("%.2f%%", heapVsContainerPercent));
                    }
                }
            }
        } catch (Exception e) {
            map.put("container.memoryLimit", "Not available: " + e.getMessage());
        }

        // Garbage Collector Details
        var gcMxBeans = ManagementFactory.getGarbageCollectorMXBeans();
        for (var gcBean : gcMxBeans) {
            String gcName = gcBean.getName();
            map.put("GC [" + gcName + "] collections", Long.toString(gcBean.getCollectionCount()));
            map.put("GC [" + gcName + "] time (ms)", Long.toString(gcBean.getCollectionTime()));
            map.put("GC [" + gcName + "] objectName", gcBean.getObjectName().toString());
        }

        // OperatingSystem MX Bean
        var osBean = (com.sun.management.OperatingSystemMXBean) ManagementFactory.getOperatingSystemMXBean();
        map.put("osMXBean.getCommittedVirtualMemorySize", bytesToMBString(osBean.getCommittedVirtualMemorySize()));
        map.put("osMXBean.getTotalMemorySize", bytesToMBString(osBean.getTotalMemorySize()));
        map.put("osMXBean.getFreeMemorySize", bytesToMBString(osBean.getFreeMemorySize()));
        map.put("osMXBean.getTotalSwapSpaceSize", bytesToMBString(osBean.getTotalSwapSpaceSize()));
        map.put("osMXBean.getFreeSwapSpaceSize", bytesToMBString(osBean.getFreeSwapSpaceSize()));
        map.put("osMXBean.getCpuLoad", String.format("%.2f%%", osBean.getCpuLoad() * 100.0));
        map.put("osMXBean.getProcessCpuLoad", String.format("%.2f%%", osBean.getProcessCpuLoad() * 100.0));
        map.put("osMXBean.getSystemLoadAverage", Double.toString(osBean.getSystemLoadAverage()));
        map.put("osMXBean.getProcessCpuTime", Double.toString(osBean.getProcessCpuTime()));
        map.put("osMXBean.getAvailableProcessors", Integer.toString(osBean.getAvailableProcessors()));

        // System Properties
        map.put("cpu_shares", System.getProperty("cpushares"));
        map.put("user.name", System.getProperty("user.name"));
        map.put("java.version", System.getProperty("java.version"));
        map.put("java.vm.name", System.getProperty("java.vm.name"));
        map.put("java.vm.version", System.getProperty("java.vm.version"));

        // Runtime Information
        map.put("jvm.uptime (ms)", Long.toString(runtimeBean.getUptime()));
        map.put("jvm.startTime", new java.util.Date(runtimeBean.getStartTime()).toString());

        return map;
    }

    // Helper method to extract JVM arguments
    private String extractJVMArg(java.util.List<String> jvmArgs, String argName) {
        return jvmArgs.stream().filter(arg -> arg.startsWith("-XX:" + argName + "=")).map(arg -> arg.substring(("-XX:" + argName + "=").length())).findFirst().orElse(null);
    }

    // Enhanced formatBytes method
    private String formatBytes(long bytes) {
        if (bytes < 0) return "Unknown";
        return String.format("%.2f", bytes / 1024.0 / 1024.0);
    }

    private String bytesToMBString(long bytes) {
        return Long.toString(bytes / 1024 / 1024) + " MB";
    }

    @GetMapping("/json")
    @ResponseBody
    Map<String, String> json() {
        return Map.of("message", "Hello, World!", "randomNumber", Integer.toString(randomNumber()));
    }

    private static int randomNumber() {
        return ThreadLocalRandom.current().nextInt(0, Integer.MAX_VALUE);
    }

    @GetMapping("/generateRandomNumbers")
    @ResponseBody
    List<Integer> generateRandomNumbers(int amount, int bound) {
        var random = ThreadLocalRandom.current();
        var numbers = new ArrayList<Integer>(amount);
        for (int i = 0; i < amount; i++) {
            numbers.add(random.nextInt(bound));
        }
        return numbers;
    }

    @GetMapping("/cpuStress")
    public Map<String, Object> cpuStress() {
        final int finalThreadCount = 10;
        final int finalDurationSeconds = 10;

        var startTime = Instant.now();
        var results = new TreeMap<String, Object>();
        results.put("threadCount", finalThreadCount);
        results.put("durationSeconds", finalDurationSeconds);
        results.put("availableProcessors", Runtime.getRuntime().availableProcessors());

        // Create a thread pool
        ExecutorService executor = Executors.newFixedThreadPool(finalThreadCount);

        try {
            // Submit CPU-intensive tasks to each thread
            List<CompletableFuture<Map<String, Object>>> futures = IntStream.range(0, finalThreadCount).mapToObj(threadId -> CompletableFuture.supplyAsync(() -> performCpuIntensiveWork(threadId, finalDurationSeconds), executor)).collect(Collectors.toList());

            // Wait for all threads to complete
            CompletableFuture<Void> allTasks = CompletableFuture.allOf(futures.toArray(new CompletableFuture[0]));

            // Collect results from all threads
            allTasks.get(finalDurationSeconds + 5, TimeUnit.SECONDS);

            List<Map<String, Object>> threadResults = futures.stream().map(CompletableFuture::join).collect(Collectors.toList());

            results.put("threadResults", threadResults);

            // Calculate totals
            long totalOperations = threadResults.stream().mapToLong(r -> (Long) r.get("operations")).sum();

            var endTime = Instant.now();
            var actualDuration = Duration.between(startTime, endTime);

            results.put("totalOperations", totalOperations);
            results.put("actualDurationMs", actualDuration.toMillis());
            results.put("operationsPerSecond", totalOperations * 1000.0 / actualDuration.toMillis());

        } catch (Exception e) {
            results.put("error", e.getMessage());
        } finally {
            executor.shutdown();
        }

        return results;
    }

    private Map<String, Object> performCpuIntensiveWork(int threadId, int durationSeconds) {
        var result = new TreeMap<String, Object>();
        result.put("threadId", threadId);

        var startTime = Instant.now();
        var endTime = startTime.plusSeconds(durationSeconds);

        long operations = 0;
        var random = ThreadLocalRandom.current();

        // Perform CPU-intensive operations until time is up
        while (Instant.now().isBefore(endTime)) {
            // Pure CPU-bound operations - no I/O or yielding

            // 1. Mathematical calculations (no memory allocation)
            double x = random.nextDouble() * 1000;
            for (int i = 0; i < 10000; i++) {
                x = Math.sin(x) * Math.cos(x) + Math.sqrt(x);
                x = Math.pow(x, 0.5) + Math.log(Math.abs(x) + 1);
            }

            // 2. Integer operations (no memory allocation)
            long sum = 0;
            for (int i = 0; i < 1000; i++) {
                sum += i * i * i;
                sum = sum % 1000000;
            }

            // 3. Prime checking (minimal memory allocation)
            long num = random.nextLong(1000000, 2000000);
            isPrimeFast(num); // Just call for CPU work, ignore result

            operations++;

            // Remove Thread.yield() - no voluntary CPU yielding
        }

        var actualEndTime = Instant.now();
        var duration = Duration.between(startTime, actualEndTime);

        result.put("operations", operations);
        result.put("durationMs", duration.toMillis());
        result.put("operationsPerSecond", operations * 1000.0 / duration.toMillis());

        return result;
    }

    private boolean isPrimeFast(long number) {
        if (number <= 1) return false;
        if (number <= 3) return true;
        if (number % 2 == 0 || number % 3 == 0) return false;

        for (long i = 5; i * i <= number; i += 6) {
            if (number % i == 0 || number % (i + 2) == 0) {
                return false;
            }
        }
        return true;
    }


    private Map<String, Object> performExtremeCpuWork(int threadId, int durationSeconds) {
        var result = new TreeMap<String, Object>();
        result.put("threadId", threadId);

        var startTime = Instant.now();
        var endTime = startTime.plusSeconds(durationSeconds);

        long operations = 0;
        var random = ThreadLocalRandom.current();

        // Extremely CPU-intensive operations - no breaks, no yielding
        while (Instant.now().isBefore(endTime)) {
            // Tight CPU loops with no I/O or yielding

            // 1. Intensive mathematical calculations
            double x = random.nextDouble() * 1000;
            for (int i = 0; i < 50000; i++) {  // Much more iterations
                x = Math.sin(x) * Math.cos(x) + Math.sqrt(x);
                x = Math.pow(x, 0.5) + Math.log(Math.abs(x) + 1);
                x = Math.atan(x) + Math.exp(x / 1000);
            }

            // 2. Prime number calculations (CPU intensive)
            long num = random.nextLong(1000000, 5000000);
            isPrimeFast(num);

            // 3. Hash calculations
            for (int i = 0; i < 1000; i++) {
                String data = String.valueOf(random.nextLong());
                data.hashCode();
            }

            // 4. Fibonacci calculations
            fibonacciIterative(random.nextInt(1000, 5000));

            operations++;

            // NO Thread.yield() - keep CPU busy continuously
        }

        var actualEndTime = Instant.now();
        var duration = Duration.between(startTime, actualEndTime);

        result.put("operations", operations);
        result.put("durationMs", duration.toMillis());
        result.put("operationsPerSecond", operations * 1000.0 / duration.toMillis());

        return result;
    }

    private long fibonacciIterative(int n) {
        if (n <= 1) return n;
        long a = 0, b = 1;
        for (int i = 2; i <= n; i++) {
            long temp = a + b;
            a = b;
            b = temp;
        }
        return b;
    }

    @GetMapping("/threadPerRequest")
    public Map<String, Object> threadPerRequestCpuWork(Integer workDurationSeconds) {
        // Default value
        final int workDuration = (workDurationSeconds != null && workDurationSeconds > 0) ? workDurationSeconds : 8;

        var startTime = Instant.now();
        var results = new TreeMap<String, Object>();
        results.put("workDuration", workDuration);
        results.put("availableProcessors", Runtime.getRuntime().availableProcessors());
        results.put("currentThread", Thread.currentThread().getName());

        // Perform CPU-heavy work directly in the request thread (lean approach)
        Map<String, Object> workResult = performDedicatedCpuWork(0, workDuration);

        var endTime = Instant.now();
        var totalDuration = Duration.between(startTime, endTime);

        // Add work results to response
        results.putAll(workResult);
        results.put("totalDurationMs", totalDuration.toMillis());

        return results;
    }

    /**
     * Performs dedicated CPU-intensive work in a single thread.
     * This simulates the work that would be done per request in a thread-per-request model.
     */
    private Map<String, Object> performDedicatedCpuWork(int requestId, int durationSeconds) {
        var result = new TreeMap<String, Object>();
        result.put("requestId", requestId);
        result.put("threadName", Thread.currentThread().getName());

        var startTime = Instant.now();
        var endTime = startTime.plusSeconds(durationSeconds);

        long operations = 0;
        var random = ThreadLocalRandom.current();

        // CPU-intensive work loop - no yielding or sleeping
        while (Instant.now().isBefore(endTime)) {
            // 1. Complex mathematical operations
            double x = random.nextDouble() * 1000;
            for (int i = 0; i < 25000; i++) {
                x = Math.sin(x) * Math.cos(x) + Math.sqrt(Math.abs(x));
                x = Math.pow(x, 0.3) + Math.log(Math.abs(x) + 1);
                x = Math.atan(x) + Math.exp(x / 10000);
            }

            // 2. Prime number checking (CPU-bound)
            long primeCandidate = random.nextLong(100000, 1000000);
            boolean isPrime = isPrimeFast(primeCandidate);

            // 3. Fibonacci calculation
            int fibN = random.nextInt(1000, 3000);
            long fibResult = fibonacciIterative(fibN);

            // 4. Hash computation for additional CPU load
            String data = String.valueOf(random.nextLong()) + fibResult + isPrime;
            // Use hash result to prevent optimization
            if (data.hashCode() > Integer.MAX_VALUE) {
                // Will never execute, but prevents dead code elimination
                operations--;
            }

            // 5. Matrix-like operations (simulated with arrays)
            performMatrixOperations(random);

            operations++;

            // Deliberately NO Thread.yield() - keep CPU maximally busy
        }

        var actualEndTime = Instant.now();
        var duration = Duration.between(startTime, actualEndTime);

        result.put("operations", operations);
        result.put("durationMs", duration.toMillis());
        result.put("operationsPerSecond", operations * 1000.0 / duration.toMillis());
        result.put("startTime", startTime.toString());
        result.put("endTime", actualEndTime.toString());

        return result;
    }

    /**
     * Simulates matrix operations for additional CPU load
     */
    private void performMatrixOperations(ThreadLocalRandom random) {
        final int size = 50; // Small matrix to avoid memory issues but still CPU intensive

        // Create and populate matrices
        double[][] matrixA = new double[size][size];
        double[][] matrixB = new double[size][size];

        for (int i = 0; i < size; i++) {
            for (int j = 0; j < size; j++) {
                matrixA[i][j] = random.nextDouble();
                matrixB[i][j] = random.nextDouble();
            }
        }

        // Perform matrix multiplication (CPU intensive)
        double[][] result = new double[size][size];
        for (int i = 0; i < size; i++) {
            for (int j = 0; j < size; j++) {
                for (int k = 0; k < size; k++) {
                    result[i][j] += matrixA[i][k] * matrixB[k][j];
                }
            }
        }

        // Calculate a simple checksum to prevent optimization
        double checksum = 0;
        for (int i = 0; i < size; i++) {
            checksum += result[i][0]; // Just use first column to avoid full iteration
        }

        // Use checksum in a way that compiler cannot optimize away
        if (checksum < -Double.MAX_VALUE) {
            // Impossible condition but prevents dead code elimination
            throw new IllegalStateException("Matrix computation error");
        }
    }

    @GetMapping("/memoryStress")
    public Map<String, Object> memoryStress(@RequestParam(defaultValue = "5000") int iterations) {
        long startTime = System.currentTimeMillis();
        var random = ThreadLocalRandom.current();
        
        // Get GC info before
        var gcBeans = ManagementFactory.getGarbageCollectorMXBeans();
        Map<String, Long> gcCountsBefore = new HashMap<>();
        Map<String, Long> gcTimesBefore = new HashMap<>();
        for (var gcBean : gcBeans) {
            gcCountsBefore.put(gcBean.getName(), gcBean.getCollectionCount());
            gcTimesBefore.put(gcBean.getName(), gcBean.getCollectionTime());
        }

        var runtime = Runtime.getRuntime();
        long memoryBefore = runtime.totalMemory() - runtime.freeMemory();
        
        // Keep some objects alive to create old generation pressure
        List<Object> survivors = new ArrayList<>();
        long totalObjects = 0;
        
        // Simple realistic web app memory allocation patterns
        for (int i = 0; i < iterations; i++) {
            
            // 1. Typical web request data (JSON-like objects)
            Map<String, Object> requestData = new HashMap<>();
            requestData.put("userId", random.nextInt(100000));
            requestData.put("sessionId", "sess_" + random.nextLong());
            requestData.put("timestamp", System.currentTimeMillis());
            requestData.put("ip", "192.168." + random.nextInt(255) + "." + random.nextInt(255));
            
            // 2. Response data simulation
            List<String> items = new ArrayList<>();
            for (int j = 0; j < random.nextInt(20) + 5; j++) {
                items.add("item_" + j + "_" + random.nextInt(1000));
            }
            requestData.put("items", items);
            
            // 3. Create some temporary processing data
            StringBuilder logMessage = new StringBuilder();
            logMessage.append("Processing request ").append(i)
                     .append(" for user ").append(requestData.get("userId"))
                     .append(" with ").append(items.size()).append(" items");
            
            // 4. Simulate caching - some objects survive longer
            if (i % 50 == 0) {
                survivors.add(requestData);
            }
            
            // 5. Create temporary arrays (common in data processing)
            if (i % 10 == 0) {
                int[] tempArray = new int[random.nextInt(500) + 100];
                for (int k = 0; k < tempArray.length; k++) {
                    tempArray[k] = random.nextInt();
                }
            }
            
            totalObjects++;
        }
        
        // Get GC info after
        Map<String, Long> gcCountsAfter = new HashMap<>();
        Map<String, Long> gcTimesAfter = new HashMap<>();
        for (var gcBean : gcBeans) {
            gcCountsAfter.put(gcBean.getName(), gcBean.getCollectionCount());
            gcTimesAfter.put(gcBean.getName(), gcBean.getCollectionTime());
        }
        
        // Calculate GC differences
        Map<String, Object> gcStats = new HashMap<>();
        long totalGcTime = 0;
        long totalGcCount = 0;
        
        for (var gcBean : gcBeans) {
            String name = gcBean.getName();
            long countDiff = gcCountsAfter.get(name) - gcCountsBefore.get(name);
            long timeDiff = gcTimesAfter.get(name) - gcTimesBefore.get(name);
            
            totalGcCount += countDiff;
            totalGcTime += timeDiff;
            
            if (countDiff > 0 || timeDiff > 0) {
                Map<String, Object> gcInfo = new HashMap<>();
                gcInfo.put("collections", countDiff);
                gcInfo.put("timeMs", timeDiff);
                gcStats.put(name, gcInfo);
            }
        }
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        long memoryAfter = runtime.totalMemory() - runtime.freeMemory();
        
        Map<String, Object> result = new HashMap<>();
        result.put("iterations", iterations);
        result.put("executionTimeMs", duration);
        result.put("objectsCreated", totalObjects);
        result.put("survivorObjects", survivors.size());
        result.put("memoryUsedBeforeMB", memoryBefore / (1024 * 1024));
        result.put("memoryUsedAfterMB", memoryAfter / (1024 * 1024));
        result.put("memoryIncreaseMB", (memoryAfter - memoryBefore) / (1024 * 1024));
        result.put("allocationsPerSecond", (double) totalObjects / (duration / 1000.0));
        result.put("totalGcCollections", totalGcCount);
        result.put("totalGcTimeMs", totalGcTime);
        result.put("gcOverheadPercent", duration > 0 ? (double) totalGcTime / duration * 100 : 0);
        result.put("gcStats", gcStats);
        result.put("timestamp", endTime);
        
        return result;
    }
}
