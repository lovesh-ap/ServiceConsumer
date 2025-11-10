package com.example.serviceconsumer.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Generic API response wrapper
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApiResponse {
    
    private String status;
    private Object data;
    private String message;
    private String error;
    private LocalDateTime timestamp;
    private Long processingTimeMs;
    
}
