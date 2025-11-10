package com.example.serviceconsumer.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Thread pool statistics
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ThreadPoolStats {
    
    private int maxThreads;
    private int activeThreads;
    private int queueSize;
    private long completedTasks;
    private boolean exhausted;
    
}
