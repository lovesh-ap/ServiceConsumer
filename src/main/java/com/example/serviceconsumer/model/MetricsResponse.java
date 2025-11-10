package com.example.serviceconsumer.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Metrics response containing thread pool and application statistics
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MetricsResponse {
    
    private ThreadPoolStats threadPool;
    private LocalDateTime timestamp;
    private String applicationName;
    private String version;
    
}
