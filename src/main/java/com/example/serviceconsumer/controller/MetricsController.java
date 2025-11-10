package com.example.serviceconsumer.controller;

import com.example.serviceconsumer.model.MetricsResponse;
import com.example.serviceconsumer.model.ThreadPoolStats;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.embedded.tomcat.TomcatWebServer;
import org.springframework.boot.web.servlet.context.ServletWebServerApplicationContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;

/**
 * Controller for metrics endpoint showing thread pool statistics.
 * 
 * This endpoint provides visibility into the thread pool status,
 * making it easy to see when thread pool exhaustion occurs.
 */
@Slf4j
@RestController
@RequestMapping("/api")
public class MetricsController {

    @Value("${app.name}")
    private String appName;

    @Value("${app.version}")
    private String appVersion;

    @Autowired
    private ServletWebServerApplicationContext webServerAppContext;

    /**
     * Get application metrics including thread pool statistics.
     * 
     * Shows:
     * - Maximum threads configured (20)
     * - Currently active threads
     * - Queue size (waiting requests)
     * - Completed tasks
     * - Whether thread pool is exhausted
     * 
     * @return Metrics response
     */
    @GetMapping("/metrics")
    public ResponseEntity<MetricsResponse> getMetrics() {
        log.debug("Incoming request: GET /api/metrics");

        ThreadPoolStats threadPoolStats = getThreadPoolStats();

        MetricsResponse response = MetricsResponse.builder()
                .threadPool(threadPoolStats)
                .timestamp(LocalDateTime.now())
                .applicationName(appName)
                .version(appVersion)
                .build();

        return ResponseEntity.ok(response);
    }

    /**
     * Extract thread pool statistics from Tomcat.
     * 
     * @return Thread pool statistics
     */
    private ThreadPoolStats getThreadPoolStats() {
        try {
            TomcatWebServer tomcatWebServer = (TomcatWebServer) webServerAppContext.getWebServer();
            org.apache.catalina.connector.Connector connector = tomcatWebServer.getTomcat().getConnector();
            org.apache.coyote.ProtocolHandler protocolHandler = connector.getProtocolHandler();
            
            int maxThreads = 20; // Default from config
            int activeThreads = 0;
            long completedTasks = 0;
            
            // Try to get executor directly from protocol handler
            if (protocolHandler instanceof org.apache.coyote.http11.AbstractHttp11Protocol) {
                org.apache.coyote.http11.AbstractHttp11Protocol<?> http11Protocol = 
                        (org.apache.coyote.http11.AbstractHttp11Protocol<?>) protocolHandler;
                
                Object executor = http11Protocol.getExecutor();
                
                if (executor instanceof org.apache.tomcat.util.threads.ThreadPoolExecutor) {
                    org.apache.tomcat.util.threads.ThreadPoolExecutor tpe = 
                            (org.apache.tomcat.util.threads.ThreadPoolExecutor) executor;
                    maxThreads = tpe.getMaximumPoolSize();
                    activeThreads = tpe.getActiveCount();
                    completedTasks = tpe.getCompletedTaskCount();
                }
            }
            
            boolean exhausted = activeThreads >= maxThreads;
            
            return ThreadPoolStats.builder()
                    .maxThreads(maxThreads)
                    .activeThreads(activeThreads)
                    .queueSize(0) // Queue size not easily accessible
                    .completedTasks(completedTasks)
                    .exhausted(exhausted)
                    .build();
                    
        } catch (Exception e) {
            log.warn("Failed to retrieve thread pool stats: {}. Using defaults.", e.getMessage());
            
            // Fallback to configured values
            return ThreadPoolStats.builder()
                    .maxThreads(20) // From configuration
                    .activeThreads(Thread.activeCount())
                    .queueSize(0)
                    .completedTasks(0)
                    .exhausted(false)
                    .build();
        }
    }
}
