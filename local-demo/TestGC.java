public class TestGC {
    public static void main(String[] args) {
        // Simple test to trigger JVM initialization
        Runtime runtime = Runtime.getRuntime();
        System.out.println("Available processors: " + runtime.availableProcessors());
        System.out.println("Max memory: " + runtime.maxMemory() / 1024 / 1024 + "MB");
        System.out.println("Total memory: " + runtime.totalMemory() / 1024 / 1024 + "MB");
    }
}
