package com.example.serviceconsumer.filter;

import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;

/**
 * Filter to generate or extract request ID and store in MDC (Mapped Diagnostic Context)
 * for consistent logging across the request lifecycle.
 * 
 * The request ID is:
 * 1. Extracted from X-Request-ID header if present
 * 2. Generated as UUID if not present
 * 3. Stored in MDC for logging
 * 4. Added to response headers
 * 5. Cleaned up after request completes
 */
@Slf4j
@Component
@Order(1)
public class RequestIdFilter extends OncePerRequestFilter {

    public static final String REQUEST_ID_HEADER = "X-Request-ID";
    public static final String REQUEST_ID_MDC_KEY = "requestId";

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                   HttpServletResponse response,
                                   FilterChain filterChain) throws ServletException, IOException {
        
        // Extract or generate request ID
        String requestId = request.getHeader(REQUEST_ID_HEADER);
        if (requestId == null || requestId.trim().isEmpty()) {
            requestId = UUID.randomUUID().toString();
        }

        // Store in MDC for logging
        MDC.put(REQUEST_ID_MDC_KEY, requestId);

        // Add to response header
        response.setHeader(REQUEST_ID_HEADER, requestId);

        try {
            // Continue with the filter chain
            filterChain.doFilter(request, response);
        } finally {
            // Clean up MDC to prevent memory leaks
            MDC.clear();
        }
    }
}
