package com.example.serviceconsumer.exception;

import com.example.serviceconsumer.model.ApiResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClientException;

import java.time.LocalDateTime;

/**
 * Global exception handler for consistent error responses.
 * 
 * This handler catches exceptions from controllers and returns
 * standardized error responses to clients.
 */
@Slf4j
@ControllerAdvice
public class GlobalExceptionHandler {

    /**
     * Handle RestTemplate timeout exceptions.
     * These occur when SlowDependency doesn't respond within the configured timeout.
     */
    @ExceptionHandler(ResourceAccessException.class)
    public ResponseEntity<ApiResponse> handleResourceAccessException(ResourceAccessException ex) {
        log.error("Resource access error: {}", ex.getMessage());
        
        ApiResponse response = ApiResponse.builder()
                .status("error")
                .message("Dependency service timed out or unreachable")
                .error(ex.getMessage())
                .timestamp(LocalDateTime.now())
                .build();
        
        return ResponseEntity.status(HttpStatus.GATEWAY_TIMEOUT).body(response);
    }

    /**
     * Handle other REST client exceptions.
     */
    @ExceptionHandler(RestClientException.class)
    public ResponseEntity<ApiResponse> handleRestClientException(RestClientException ex) {
        log.error("REST client error: {}", ex.getMessage());
        
        ApiResponse response = ApiResponse.builder()
                .status("error")
                .message("Failed to communicate with dependency service")
                .error(ex.getMessage())
                .timestamp(LocalDateTime.now())
                .build();
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }

    /**
     * Handle all other unexpected exceptions.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse> handleGenericException(Exception ex) {
        log.error("Unexpected error: {}", ex.getMessage(), ex);
        
        ApiResponse response = ApiResponse.builder()
                .status("error")
                .message("An unexpected error occurred")
                .error(ex.getMessage())
                .timestamp(LocalDateTime.now())
                .build();
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }
}
