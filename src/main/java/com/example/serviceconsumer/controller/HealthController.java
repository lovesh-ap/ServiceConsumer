package com.example.serviceconsumer.controller;

import com.example.serviceconsumer.model.HealthResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;

/**
 * Controller for the CONTROL endpoint (health check).
 * 
 * This endpoint has NO external dependencies and should always be fast.
 * However, it demonstrates the cascading failure problem:
 * 
 * - In healthy state: Responds in <10ms
 * - During thread pool exhaustion: HANGS indefinitely (no available threads)
 * 
 * This proves that even completely independent endpoints become victims
 * of thread pool starvation when other endpoints block all threads.
 */
@Slf4j
@RestController
@RequestMapping("/api")
public class HealthController {

    /**
     * Simple health check endpoint with NO external dependencies.
     * 
     * CONTROL ENDPOINT - Should always be fast, but won't be during thread starvation.
     * 
     * This endpoint:
     * - Does NOT call any external services
     * - Does NOT perform any I/O operations
     * - Just returns a simple response
     * 
     * Yet, when all threads are blocked waiting for SlowDependency,
     * this endpoint becomes unreachable because there are no free threads
     * to process the request.
     * 
     * @return Health status
     */
    @GetMapping("/health")
    public ResponseEntity<HealthResponse> health() {
        log.info("Incoming request: GET /api/health - Thread: {}", 
                Thread.currentThread().getName());
        
        HealthResponse response = HealthResponse.builder()
                .status("UP")
                .timestamp(LocalDateTime.now())
                .message("Application is healthy")
                .build();
        
        log.info("Response: GET /api/health - Status: 200");
        
        return ResponseEntity.ok(response);
    }
}
