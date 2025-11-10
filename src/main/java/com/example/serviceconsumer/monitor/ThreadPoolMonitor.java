package com.example.serviceconsumer.monitor;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.web.embedded.tomcat.TomcatWebServer;
import org.springframework.boot.web.servlet.context.ServletWebServerApplicationContext;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Scheduled task to monitor thread pool status.
 * 
 * This component logs thread pool statistics every 30 seconds to help
 * identify gradual degradation and thread pool exhaustion over time.
 * 
 * The logs show:
 * - Active threads vs max threads
 * - Whether pool is exhausted
 * - Warnings when threads are near capacity
 * 
 * This helps demonstrate how the application slowly degrades under sustained
 * load until it reaches complete thread pool starvation.
 */
@Slf4j
@Component
public class ThreadPoolMonitor {

    @Autowired
    private ServletWebServerApplicationContext webServerAppContext;

    /**
     * Log thread pool statistics every 30 seconds.
     * 
     * This runs in the background and provides visibility into the
     * gradual degradation of the thread pool under load.
     */
    @Scheduled(fixedRate = 30000) // Every 30 seconds
    public void logThreadPoolStatus() {
        try {
            TomcatWebServer tomcatWebServer = (TomcatWebServer) webServerAppContext.getWebServer();
            org.apache.catalina.connector.Connector connector = tomcatWebServer.getTomcat().getConnector();
            org.apache.coyote.ProtocolHandler protocolHandler = connector.getProtocolHandler();
            
            // Try to get executor directly from protocol handler
            Object executor = null;
            int maxThreads = 20; // Default from config
            int activeThreads = 0;
            
            try {
                // Try different methods to get thread pool info based on Tomcat version
                if (protocolHandler instanceof org.apache.coyote.http11.AbstractHttp11Protocol) {
                    org.apache.coyote.http11.AbstractHttp11Protocol<?> http11Protocol = 
                            (org.apache.coyote.http11.AbstractHttp11Protocol<?>) protocolHandler;
                    
                    executor = http11Protocol.getExecutor();
                    
                    if (executor instanceof org.apache.tomcat.util.threads.ThreadPoolExecutor) {
                        org.apache.tomcat.util.threads.ThreadPoolExecutor tpe = 
                                (org.apache.tomcat.util.threads.ThreadPoolExecutor) executor;
                        maxThreads = tpe.getMaximumPoolSize();
                        activeThreads = tpe.getActiveCount();
                    }
                }
            } catch (Exception e) {
                // Fallback: use JVM thread count as approximation
                activeThreads = Thread.activeCount();
            }
            
            // Calculate thread pool utilization percentage
            int utilization = maxThreads > 0 ? (int) ((activeThreads * 100.0) / maxThreads) : 0;
            
            // Log with appropriate level based on utilization
            if (activeThreads >= maxThreads) {
                log.warn("⚠️  THREAD POOL EXHAUSTED! Active: {}/{} (100%) [ALL THREADS BUSY]",
                        activeThreads, maxThreads);
            } else if (utilization >= 80) {
                log.warn("Thread Pool Status: Active: {}/{} ({}%) [HIGH LOAD]",
                        activeThreads, maxThreads, utilization);
            } else if (utilization >= 50) {
                log.info("Thread Pool Status: Active: {}/{} ({}%) [MODERATE LOAD]",
                        activeThreads, maxThreads, utilization);
            } else {
                log.info("Thread Pool Status: Active: {}/{} ({}%) [HEALTHY]",
                        activeThreads, maxThreads, utilization);
            }
            
        } catch (Exception e) {
            log.debug("Could not retrieve thread pool stats: {}", e.getMessage());
        }
    }
}
