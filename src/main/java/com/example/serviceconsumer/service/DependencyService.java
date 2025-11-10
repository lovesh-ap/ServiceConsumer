package com.example.serviceconsumer.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

/**
 * Service layer for calling SlowDependency.
 * 
 * This service demonstrates how blocking HTTP calls can exhaust thread pools
 * when the downstream service becomes slow or unresponsive.
 * 
 * Key behaviors:
 * - Logs all calls with timing information
 * - Uses RestTemplate (blocking/synchronous)
 * - Waits for configured timeout (3 seconds) when dependency hangs
 * - Each call blocks a Tomcat worker thread during the wait
 */
@Slf4j
@Service
public class DependencyService {

    @Value("${dependency.service.url}")
    private String dependencyServiceUrl;

    @Autowired
    private RestTemplate restTemplate;

    /**
     * Fetch data from SlowDependency service.
     * 
     * This is a BLOCKING call that will wait up to 3 seconds (read timeout)
     * for a response. If SlowDependency hangs, this thread will be blocked
     * for the entire timeout period.
     * 
     * @return Data from SlowDependency
     * @throws RestClientException if call fails or times out
     */
    public String fetchDataFromDependency() {
        long startTime = System.currentTimeMillis();
        
        log.debug("Calling SlowDependency at: {}", dependencyServiceUrl);
        
        try {
            // This is a BLOCKING call - thread waits here
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restTemplate.getForObject(
                    dependencyServiceUrl, 
                    Map.class
            );
            
            long duration = System.currentTimeMillis() - startTime;
            log.debug("SlowDependency call succeeded - Duration: {}ms", duration);
            
            if (response != null && response.containsKey("message")) {
                return (String) response.get("message");
            } else {
                return "Data received from SlowDependency";
            }
            
        } catch (RestClientException e) {
            long duration = System.currentTimeMillis() - startTime;
            log.error("SlowDependency call failed - Duration: {}ms - Error: {}", 
                    duration, e.getMessage());
            throw e;
        }
    }
}
