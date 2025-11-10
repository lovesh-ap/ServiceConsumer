package com.example.serviceconsumer.config;

import com.example.serviceconsumer.interceptor.RestTemplateRequestIdInterceptor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.List;

/**
 * Configuration for RestTemplate with timeouts and request ID propagation.
 * 
 * This configuration creates a RestTemplate that:
 * - Has a 2-second connection timeout
 * - Has a 3-second read timeout
 * - Propagates request IDs to downstream services
 * - Logs all outbound HTTP calls
 * 
 * These timeouts are intentionally set to demonstrate thread pool starvation
 * when the downstream service (SlowDependency) hangs.
 */
@Slf4j
@Configuration
public class RestTemplateConfig {

    @Value("${http.client.connect-timeout}")
    private int connectTimeout;

    @Value("${http.client.read-timeout}")
    private int readTimeout;

    @Autowired
    private RestTemplateRequestIdInterceptor requestIdInterceptor;

    @Bean
    public RestTemplate restTemplate() {
        // Create request factory with timeouts
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(connectTimeout);
        factory.setReadTimeout(readTimeout);

        log.info("RestTemplate configured with connectTimeout={}ms, readTimeout={}ms",
                connectTimeout, readTimeout);

        // Create RestTemplate with factory
        RestTemplate restTemplate = new RestTemplate(factory);

        // Add interceptors
        List<ClientHttpRequestInterceptor> interceptors = new ArrayList<>();
        interceptors.add(requestIdInterceptor);
        restTemplate.setInterceptors(interceptors);

        return restTemplate;
    }
}
