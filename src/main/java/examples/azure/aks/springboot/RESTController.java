package examples.azure.aks.springboot;

import static java.lang.Runtime.getRuntime;

import java.lang.management.ManagementFactory;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
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
    public Map<String, String> inspect() throws ClassNotFoundException {
        var map = new TreeMap<String, String>();
        var runtime = getRuntime();

        // Current GC
        var gcIdentifier = new IdentifyCurrentGC();
        map.put("Running GC", gcIdentifier.identifyGC().name());

        var podIP = System.getenv("MY_POD_IP");
        map.put("podIP", podIP);

        // CPUs and Memory

        map.put("availableProcessors", Integer.toString(runtime.availableProcessors()));
        map.put("maxMemory (MB)", Long.toString(runtime.maxMemory() / 1024 / 1024));
        map.put("totalMemory (MB)", Long.toString(runtime.totalMemory() / 1024 / 1024));

        // Garbage Collector
        var gcMxBeans = ManagementFactory.getGarbageCollectorMXBeans();
        for (var gcBean : gcMxBeans) {
            map.put("GC [" + gcBean.getName() + "]", gcBean.getObjectName().toString());
        }

        // OperatingSystem MX Bean
        var osBean = (com.sun.management.OperatingSystemMXBean) ManagementFactory.getOperatingSystemMXBean();
        map.put("osMXBean.getCommittedVirtualMemorySize", bytesToMBString(osBean.getCommittedVirtualMemorySize()));
        map.put("osMXBean.getTotalMemorySize", bytesToMBString(osBean.getTotalMemorySize()));
        map.put("osMXBean.getFreeMemorySize", bytesToMBString(osBean.getFreeMemorySize()));
        map.put("osMXBean.getTotalSwapSpaceSize", bytesToMBString(osBean.getTotalSwapSpaceSize()));
        map.put("osMXBean.getFreeSwapSpaceSize", bytesToMBString(osBean.getFreeSwapSpaceSize()));
        map.put("osMXBean.getCpuLoad", Double.toString(osBean.getCpuLoad() * 100.0));
        map.put("osMXBean.getProcessCpuLoad", Double.toString(osBean.getProcessCpuLoad()));
        map.put("osMXBean.getSystemLoadAverage", Double.toString(osBean.getSystemLoadAverage()));
        map.put("osMXBean.getProcessCpuTime", Double.toString(osBean.getProcessCpuTime()));
        map.put("osMXBean.getAvailableProcessors", Integer.toString(osBean.getAvailableProcessors()));

        map.put("cpu_shares", System.getProperty("cpushares"));

        // current user
        map.put("user.name", System.getProperty("user.name"));

        return map;
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
            List<CompletableFuture<Map<String, Object>>> futures = IntStream.range(0, finalThreadCount)
                    .mapToObj(threadId -> CompletableFuture.supplyAsync(() ->
                            performCpuIntensiveWork(threadId, finalDurationSeconds), executor))
                    .collect(Collectors.toList());

            // Wait for all threads to complete
            CompletableFuture<Void> allTasks = CompletableFuture.allOf(
                    futures.toArray(new CompletableFuture[0]));

            // Collect results from all threads
            allTasks.get(finalDurationSeconds + 5, TimeUnit.SECONDS);

            List<Map<String, Object>> threadResults = futures.stream()
                    .map(CompletableFuture::join)
                    .collect(Collectors.toList());

            results.put("threadResults", threadResults);

            // Calculate totals
            long totalOperations = threadResults.stream()
                    .mapToLong(r -> (Long) r.get("operations"))
                    .sum();

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
    public Map<String, Object> memoryStress(@RequestParam(defaultValue = "10") int durationSeconds,
                                           @RequestParam(defaultValue = "1000") int objectSizeKB) {
        var startTime = Instant.now();
        var results = new TreeMap<String, Object>();
        results.put("durationSeconds", durationSeconds);
        results.put("objectSizeKB", objectSizeKB);
        results.put("availableProcessors", Runtime.getRuntime().availableProcessors());
        
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
        
        try {
            // Create lots of objects to trigger GC
            var objectList = new ArrayList<byte[]>();
            var endTime = startTime.plusSeconds(durationSeconds);
            long totalAllocations = 0;
            
            while (Instant.now().isBefore(endTime)) {
                // Create large objects that will stress the heap
                for (int i = 0; i < 100; i++) {
                    objectList.add(new byte[objectSizeKB * 1024]);
                    totalAllocations++;
                    
                    // Occasionally clear some objects to create churn
                    if (objectList.size() > 1000) {
                        objectList.subList(0, 500).clear();
                    }
                }
                
                // Create additional memory pressure with temporary objects
                for (int i = 0; i < 500; i++) {
                    var tempString = "temporary-object-" + i + "-" + System.nanoTime();
                    // Create temporary arrays to add memory pressure
                    @SuppressWarnings("unused")
                    int len = tempString.split("-").length; // Just use the result
                }
            }
            
            results.put("totalAllocations", totalAllocations);
            results.put("finalListSize", objectList.size());
            
        } catch (OutOfMemoryError e) {
            results.put("error", "OutOfMemoryError: " + e.getMessage());
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
        for (var gcBean : gcBeans) {
            String name = gcBean.getName();
            long countDiff = gcCountsAfter.get(name) - gcCountsBefore.get(name);
            long timeDiff = gcTimesAfter.get(name) - gcTimesBefore.get(name);
            
            Map<String, Object> gcInfo = new HashMap<>();
            gcInfo.put("collections", countDiff);
            gcInfo.put("timeMs", timeDiff);
            gcStats.put(name, gcInfo);
        }
        
        var endTime = Instant.now();
        long memoryAfter = runtime.totalMemory() - runtime.freeMemory();
        
        results.put("gcStats", gcStats);
        results.put("memoryUsedBeforeMB", memoryBefore / 1024 / 1024);
        results.put("memoryUsedAfterMB", memoryAfter / 1024 / 1024);
        results.put("actualDurationMs", Duration.between(startTime, endTime).toMillis());
        
        return results;
    }

    @GetMapping("/gcStress")
    public Map<String, Object> gcStress(
            @RequestParam(defaultValue = "10000") int iterations,
            @RequestParam(defaultValue = "1000") int arraySize,
            @RequestParam(defaultValue = "true") boolean includeStrings,
            @RequestParam(defaultValue = "true") boolean includeCollections,
            @RequestParam(defaultValue = "true") boolean includeLargeObjects) {
        
        long startTime = System.currentTimeMillis();
        long totalAllocated = 0;
        List<Object> longLivedObjects = new ArrayList<>();
        
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
        
        // Memory allocation patterns that stress different GC scenarios
        for (int i = 0; i < iterations; i++) {
            
            // 1. Short-lived array allocation (Eden space pressure)
            int[] array = new int[arraySize];
            for (int j = 0; j < arraySize; j++) {
                array[j] = j * i;
            }
            totalAllocated += arraySize * 4;
            
            // 2. String operations (realistic web app pattern)
            if (includeStrings && i % 10 == 0) {
                StringBuilder sb = new StringBuilder();
                for (int k = 0; k < 50; k++) {
                    sb.append("User_").append(i).append("_Request_").append(k).append("_Data");
                }
                String result = sb.toString();
                totalAllocated += result.length() * 2; // 2 bytes per char in UTF-16
                
                // Some strings survive longer (old generation pressure)
                if (i % 100 == 0) {
                    longLivedObjects.add(result);
                }
            }
            
            // 3. Collection operations (typical business logic)
            if (includeCollections && i % 20 == 0) {
                Map<String, Object> customerData = new HashMap<>();
                customerData.put("id", i);
                customerData.put("name", "Customer_" + i);
                customerData.put("email", "customer" + i + "@example.com");
                
                List<Map<String, Object>> orders = new ArrayList<>();
                for (int orderIdx = 0; orderIdx < 5; orderIdx++) {
                    Map<String, Object> order = new HashMap<>();
                    order.put("orderId", i * 1000 + orderIdx);
                    order.put("amount", Math.random() * 1000);
                    order.put("items", createOrderItems(orderIdx + 1));
                    orders.add(order);
                }
                customerData.put("orders", orders);
                
                totalAllocated += estimateObjectSize(customerData);
                
                // Keep some customers in memory (survivor space testing)
                if (i % 500 == 0) {
                    longLivedObjects.add(customerData);
                }
            }
            
            // 4. Large object allocation (LOH pressure)
            if (includeLargeObjects && i % 1000 == 0) {
                byte[] largeArray = new byte[1024 * 1024]; // 1MB allocation
                for (int b = 0; b < largeArray.length; b += 1024) {
                    largeArray[b] = (byte) (i % 256);
                }
                totalAllocated += largeArray.length;
            }
            
            // 5. Nested object creation (object graph complexity)
            if (i % 50 == 0) {
                createNestedObjects(3, i);
                totalAllocated += 1024; // Estimate
            }
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
        for (var gcBean : gcBeans) {
            String name = gcBean.getName();
            long countDiff = gcCountsAfter.get(name) - gcCountsBefore.get(name);
            long timeDiff = gcTimesAfter.get(name) - gcTimesBefore.get(name);
            
            Map<String, Object> gcInfo = new HashMap<>();
            gcInfo.put("collections", countDiff);
            gcInfo.put("timeMs", timeDiff);
            gcStats.put(name, gcInfo);
        }
        
        long endTime = System.currentTimeMillis();
        long memoryAfter = runtime.totalMemory() - runtime.freeMemory();
        
        Map<String, Object> result = new HashMap<>();
        result.put("iterations", iterations);
        result.put("arraySize", arraySize);
        result.put("executionTimeMs", endTime - startTime);
        result.put("totalAllocatedBytes", totalAllocated);
        result.put("allocatedMB", totalAllocated / (1024 * 1024));
        result.put("memoryUsedBeforeMB", memoryBefore / 1024 / 1024);
        result.put("memoryUsedAfterMB", memoryAfter / 1024 / 1024);
        result.put("longLivedObjectsCount", longLivedObjects.size());
        result.put("includeStrings", includeStrings);
        result.put("includeCollections", includeCollections);
        result.put("includeLargeObjects", includeLargeObjects);
        result.put("timestamp", System.currentTimeMillis());
        result.put("allocationsPerSecond", (double) iterations / ((endTime - startTime) / 1000.0));
        result.put("gcStats", gcStats);
        
        return result;
    }
    
    private List<Map<String, Object>> createOrderItems(int count) {
        List<Map<String, Object>> items = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            Map<String, Object> item = new HashMap<>();
            item.put("itemId", "ITEM_" + i);
            item.put("description", "Product description for item " + i);
            item.put("price", Math.random() * 100);
            item.put("quantity", (int) (Math.random() * 10) + 1);
            items.add(item);
        }
        return items;
    }
    
    private void createNestedObjects(int depth, int seed) {
        if (depth <= 0) return;
        
        Map<String, Object> node = new HashMap<>();
        node.put("level", depth);
        node.put("data", "Node_" + seed + "_" + depth);
        node.put("timestamp", System.currentTimeMillis());
        
        if (depth > 1) {
            List<Object> children = new ArrayList<>();
            for (int i = 0; i < 3; i++) {
                children.add(createNestedObjectHelper(depth - 1, seed * 10 + i));
            }
            node.put("children", children);
        }
    }
    
    private Map<String, Object> createNestedObjectHelper(int depth, int seed) {
        Map<String, Object> node = new HashMap<>();
        node.put("level", depth);
        node.put("data", "Node_" + seed + "_" + depth);
        
        if (depth > 1) {
            List<Object> children = new ArrayList<>();
            for (int i = 0; i < 2; i++) {
                children.add(createNestedObjectHelper(depth - 1, seed * 10 + i));
            }
            node.put("children", children);
        }
        return node;
    }
    
    private long estimateObjectSize(Object obj) {
        // Rough estimation for demonstration purposes
        if (obj instanceof Map) {
            return ((Map<?, ?>) obj).size() * 64; // Rough estimate
        } else if (obj instanceof List) {
            return ((List<?>) obj).size() * 32; // Rough estimate
        } else if (obj instanceof String) {
            return ((String) obj).length() * 2 + 24; // UTF-16 + object overhead
        }
        return 32; // Default object overhead estimate
    }
}
