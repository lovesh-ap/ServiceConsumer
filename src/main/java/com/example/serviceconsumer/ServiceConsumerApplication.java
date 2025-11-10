package com.example.serviceconsumer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * ServiceConsumer Application - Demonstrates thread pool starvation
 * 
 * This application demonstrates how a microservice can become completely
 * unresponsive when its dependencies fail, causing cascading failures
 * through thread pool exhaustion.
 * 
 * Key behaviors:
 * - Vulnerable endpoint (/api/process-data) calls SlowDependency
 * - Control endpoint (/api/health) has no external dependencies
 * - Under load, when SlowDependency hangs, ALL threads get blocked
 * - Even /api/health becomes unreachable (thread pool starvation)
 */
@SpringBootApplication
@EnableScheduling
public class ServiceConsumerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ServiceConsumerApplication.class, args);
    }

}
