package com.example.serviceconsumer.controller;

import com.example.serviceconsumer.model.ApiResponse;
import com.example.serviceconsumer.service.DependencyService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;

/**
 * Controller for the VULNERABLE endpoint that calls SlowDependency.
 * 
 * This endpoint demonstrates thread pool starvation:
 * - Makes a blocking HTTP call to SlowDependency
 * - When SlowDependency hangs, this thread waits for 3 seconds (timeout)
 * - Under heavy load (50+ concurrent requests), all 20 threads get blocked
 * - Once all threads are blocked, NO requests can be processed (not even /api/health)
 * 
 * This is the PRIMARY endpoint to demonstrate the cascading failure pattern.
 */
@Slf4j
@RestController
@RequestMapping("/api")
public class DataController {

    @Autowired
    private DependencyService dependencyService;

    /**
     * Process data by fetching information from SlowDependency.
     * 
     * VULNERABLE ENDPOINT - This is where thread starvation occurs.
     * 
     * Normal behavior: Returns data in ~100-200ms
     * Failure behavior: Waits 3 seconds (timeout), then returns error
     * Under load + failure: All threads blocked, entire app becomes unresponsive
     * 
     * @return API response with data or error
     */
    @GetMapping("/process-data")
    public ResponseEntity<ApiResponse> processData() {
        long startTime = System.currentTimeMillis();
        
        log.info("Incoming request: GET /api/process-data - Thread: {}", 
                Thread.currentThread().getName());
        
        try {
            // BLOCKING CALL - Thread waits here for response or timeout
            String data = dependencyService.fetchDataFromDependency();
            
            long processingTime = System.currentTimeMillis() - startTime;
            
            ApiResponse response = ApiResponse.builder()
                    .status("success")
                    .data(data)
                    .message("Data processed successfully")
                    .timestamp(LocalDateTime.now())
                    .processingTimeMs(processingTime)
                    .build();
            
            log.info("Response: GET /api/process-data - Status: 200 - Duration: {}ms", 
                    processingTime);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            long processingTime = System.currentTimeMillis() - startTime;
            
            log.error("Request failed: GET /api/process-data - Duration: {}ms - Error: {}", 
                    processingTime, e.getMessage());
            
            ApiResponse response = ApiResponse.builder()
                    .status("error")
                    .message("Failed to fetch data from dependency")
                    .error(e.getMessage())
                    .timestamp(LocalDateTime.now())
                    .processingTimeMs(processingTime)
                    .build();
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
}
