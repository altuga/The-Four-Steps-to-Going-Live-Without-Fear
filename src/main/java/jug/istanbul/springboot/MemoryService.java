package jug.istanbul.springboot;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

import io.micrometer.core.instrument.MeterRegistry;

@Service
public class MemoryService {
    private static final Logger logger = LoggerFactory.getLogger(MemoryService.class);
    private final List<byte[]> memoryList = new ArrayList<>();
    private static final int MB = 1024 * 1024;

    public MemoryService(MeterRegistry registry) {
        registry.gauge("memory.list.size", memoryList, List::size);
    }

    @Scheduled(fixedRate = 100)
    public void simulateMemoryLoad() {
        try {
            // Allocate 1MB
            memoryList.add(new byte[MB]);

            // Release memory when too large
            if (memoryList.size() > 100) {
                memoryList.subList(0, 50).clear();
            }

            logger.info("Current memory list size: {}", memoryList.size());
        } catch (OutOfMemoryError e) {
            logger.error("OutOfMemoryError occurred", e);
            memoryList.clear();
        }
    }

    public void generateLoad(int mbSize) {
        List <byte[]> tempList = new ArrayList<>();
        try {
            for (int i = 0; i < mbSize; i++) {
                tempList.add(new byte[MB]);
                if (i % 10 == 0) {
                    logger.info("Allocated {}MB", i);
                }
            }
            //Thread.sleep(1000); // Hold memory for a second
        //} catch (InterruptedException e) {
           // Thread.currentThread().interrupt();
        } finally {
          //  tempList.clear();
        }
    }
}
