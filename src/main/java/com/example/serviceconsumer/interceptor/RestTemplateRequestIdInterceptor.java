package com.example.serviceconsumer.interceptor;

import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.http.HttpRequest;
import org.springframework.http.client.ClientHttpRequestExecution;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * RestTemplate interceptor to:
 * 1. Propagate request ID to outbound HTTP calls
 * 2. Log outbound request details
 * 3. Log response status and timing
 */
@Slf4j
@Component
public class RestTemplateRequestIdInterceptor implements ClientHttpRequestInterceptor {

    private static final String REQUEST_ID_HEADER = "X-Request-ID";
    private static final String REQUEST_ID_MDC_KEY = "requestId";

    @Override
    public ClientHttpResponse intercept(HttpRequest request, byte[] body,
                                        ClientHttpRequestExecution execution) throws IOException {
        
        // Propagate request ID to outbound call
        String requestId = MDC.get(REQUEST_ID_MDC_KEY);
        if (requestId != null) {
            request.getHeaders().add(REQUEST_ID_HEADER, requestId);
        }

        // Log outbound request
        long startTime = System.currentTimeMillis();
        log.debug("Outbound HTTP request: {} {}", request.getMethod(), request.getURI());

        ClientHttpResponse response = null;
        try {
            // Execute the request
            response = execution.execute(request, body);
            
            // Log response
            long duration = System.currentTimeMillis() - startTime;
            log.debug("Outbound HTTP response: {} {} - Status: {} - Duration: {}ms",
                    request.getMethod(), request.getURI(), response.getStatusCode(), duration);
            
            return response;
        } catch (IOException e) {
            // Log error
            long duration = System.currentTimeMillis() - startTime;
            log.error("Outbound HTTP request failed: {} {} - Duration: {}ms - Error: {}",
                    request.getMethod(), request.getURI(), duration, e.getMessage());
            throw e;
        }
    }
}
