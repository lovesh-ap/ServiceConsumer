# ServiceConsumer

A Spring Boot application demonstrating **thread pool starvation** and **cascading failures** in microservices architecture.

## 📋 Overview

ServiceConsumer is the "victim" application that demonstrates how a microservice can become completely unresponsive when its dependencies fail. This happens through **thread pool exhaustion** - when all worker threads become blocked waiting for a slow or unresponsive dependency.

### Key Demonstration

When SlowDependency stops responding:
1. Requests to `/api/process-data` wait for 3 seconds (timeout) before failing
2. Under heavy load (50+ concurrent requests), all 20 threads become blocked
3. **Even `/api/health` becomes unreachable** - despite having NO dependency on SlowDependency
4. The entire application becomes unresponsive

This demonstrates the **cascading failure** problem in microservices.

---

## 🏗️ Architecture

### Technology Stack
- **Java**: 8
- **Spring Boot**: 2.3.12.RELEASE
- **Build Tool**: Maven
- **HTTP Client**: RestTemplate (synchronous/blocking)
- **Server**: Embedded Tomcat (20 worker threads)

### Configuration Highlights
- **Max Threads**: 20 (realistic for production-like behavior)
- **Connect Timeout**: 2 seconds
- **Read Timeout**: 3 seconds
- **Log Files**: 50MB per file, 250MB total (5 files)

---

## 📂 Project Structure

```
ServiceConsumer/
├── src/main/java/com/example/serviceconsumer/
│   ├── ServiceConsumerApplication.java       # Main application
│   ├── controller/
│   │   ├── DataController.java               # Vulnerable endpoint
│   │   ├── HealthController.java             # Control endpoint
│   │   └── MetricsController.java            # Thread pool metrics
│   ├── service/
│   │   └── DependencyService.java            # Calls SlowDependency
│   ├── filter/
│   │   └── RequestIdFilter.java              # Request ID tracking
│   ├── interceptor/
│   │   └── RestTemplateRequestIdInterceptor.java
│   ├── monitor/
│   │   └── ThreadPoolMonitor.java            # Scheduled monitoring
│   ├── config/
│   │   └── RestTemplateConfig.java           # HTTP client config
│   ├── model/
│   │   ├── ApiResponse.java
│   │   ├── HealthResponse.java
│   │   ├── MetricsResponse.java
│   │   └── ThreadPoolStats.java
│   └── exception/
│       └── GlobalExceptionHandler.java
└── src/main/resources/
    └── application.properties                # Configuration
```

---

## 🚀 Getting Started

### Prerequisites
- Java 8 or higher
- Maven 3.6+
- SlowDependency app running on port 8081

### Build the Application

```bash
mvn clean package
```

### Run the Application

```bash
mvn spring-boot:run
```

Or run the JAR:

```bash
java -jar target/service-consumer-1.0.0.jar
```

The application will start on **http://localhost:8080**

---

## 🔌 Endpoints

### Application Endpoints

#### 1. Vulnerable Endpoint (Demonstrates Thread Starvation)
```bash
GET http://localhost:8080/api/process-data
```

**Behavior:**
- Calls SlowDependency to fetch data
- **Normal**: Returns in ~100-200ms
- **When SlowDependency hangs**: Waits 3 seconds (timeout), then returns error
- **Under load**: Exhausts all threads, making entire app unresponsive

**Example Response (Success):**
```json
{
  "status": "success",
  "data": "Data from SlowDependency",
  "message": "Data processed successfully",
  "timestamp": "2025-11-10T10:30:45.123",
  "processingTimeMs": 150
}
```

**Example Response (Failure):**
```json
{
  "status": "error",
  "message": "Failed to fetch data from dependency",
  "error": "Read timed out",
  "timestamp": "2025-11-10T10:30:48.168",
  "processingTimeMs": 3012
}
```

#### 2. Control Endpoint (Healthy but Affected by Starvation)
```bash
GET http://localhost:8080/api/health
```

**Behavior:**
- NO external dependencies
- **Normal**: Returns in <10ms
- **During thread starvation**: HANGS (no available threads)

**Response:**
```json
{
  "status": "UP",
  "timestamp": "2025-11-10T10:30:45.123",
  "message": "Application is healthy"
}
```

#### 3. Metrics Endpoint
```bash
GET http://localhost:8080/api/metrics
```

**Response:**
```json
{
  "threadPool": {
    "maxThreads": 20,
    "activeThreads": 15,
    "queueSize": 0,
    "completedTasks": 1234,
    "exhausted": false
  },
  "timestamp": "2025-11-10T10:30:45.123",
  "applicationName": "ServiceConsumer",
  "version": "1.0.0"
}
```

### Actuator Endpoints

#### Health Check
```bash
GET http://localhost:8080/actuator/health
```

#### Thread Pool Metrics
```bash
# Get active threads
GET http://localhost:8080/actuator/metrics/tomcat.threads.busy

# Get max threads
GET http://localhost:8080/actuator/metrics/tomcat.threads.config.max
```

#### Thread Dump (THE SMOKING GUN 🔥)
```bash
GET http://localhost:8080/actuator/threaddump
```

During thread starvation, this shows ALL threads blocked waiting for SlowDependency!

---

## 🎬 Demo Scripts

Three bash scripts are provided for easy demonstration:

### 1. Quick Test Script (`test.sh`)
Quick verification that all endpoints are working:
```bash
./test.sh
```

Tests:
- ✓ `/api/health` endpoint
- ✓ `/api/process-data` endpoint
- ✓ `/api/metrics` endpoint
- ✓ Actuator endpoints

---

### 2. Interactive Demo Script (`demo.sh`)
Full guided demonstration with explanations:
```bash
./demo.sh
```

This script walks through:
1. **Scenario 1**: Baseline (healthy state)
2. **Scenario 2**: Single request timeout
3. **Scenario 3**: Thread pool exhaustion (the main demo)

Features:
- Color-coded output
- Interactive (press ENTER to continue)
- Automatic thread pool monitoring
- Thread dump analysis
- Clear observations and takeaways

---

### 3. Load Test Script (`load-test.sh`)
Automated load testing to trigger thread pool exhaustion:
```bash
./load-test.sh [concurrent_requests]

# Examples:
./load-test.sh 50    # Default: 50 concurrent requests
./load-test.sh 100   # Heavier load: 100 concurrent requests
```

What it does:
1. Launches N concurrent requests to `/api/process-data`
2. Monitors thread pool during load
3. Tests if `/api/health` is accessible (should hang!)
4. Captures thread dump for analysis
5. Waits for recovery

Output:
- Real-time request completion logs
- Thread pool statistics before/during/after
- Thread dump saved to file
- Total execution time

---

## 🧪 Manual Demo Scenarios

### Scenario 1: Baseline (Everything Healthy)

**Prerequisites:** SlowDependency running normally on port 8081

```bash
# Test health endpoint - should be fast
curl http://localhost:8080/api/health

# Test data endpoint - should be fast
curl http://localhost:8080/api/process-data

# Check thread pool - should show low activity
curl http://localhost:8080/api/metrics
```

**Expected:**
- All requests complete in <200ms
- Thread pool shows 1-2 active threads

---

### Scenario 2: Single Request Timeout

**Prerequisites:** SlowDependency in "hang" mode

```bash
# Single request - will timeout after 3 seconds
curl http://localhost:8080/api/process-data

# Health endpoint should still work (threads available)
curl http://localhost:8080/api/health
```

**Expected:**
- `/api/process-data` takes 3 seconds, returns error
- `/api/health` still fast (threads available)

---

### Scenario 3: Thread Pool Exhaustion ⚠️ **THE MAIN DEMO**

**Prerequisites:** SlowDependency in "hang" mode

**Terminal 1: Monitor Logs**
```bash
tail -f logs/serviceconsumer.log
```

**Terminal 2: Flood with Requests**
```bash
# Send 50 concurrent requests (more than 20 threads)
for i in {1..50}; do 
  curl http://localhost:8080/api/process-data & 
done
```

**Terminal 3: Try Health Endpoint**
```bash
# This should HANG! No threads available!
curl http://localhost:8080/api/health
```

**Terminal 4: Check Thread Dump**
```bash
# Shows all 20 threads blocked
curl http://localhost:8080/actuator/threaddump
```

**Expected Results:**
1. All 50 requests start simultaneously
2. First 20 requests grab all available threads
3. Remaining 30 requests queue up
4. All 20 threads block waiting for SlowDependency (3-second timeout)
5. `/api/health` request **cannot be processed** (no free threads)
6. Thread dump shows all threads in `TIMED_WAITING` or `RUNNABLE` state with stack traces pointing to `RestTemplate` socket reads
7. After 3 seconds, first batch fails, next batch starts (continues until all 50 complete)

**Log Evidence:**
```log
2025-11-10 10:30:00.000 [http-nio-8080-exec-1] [uuid-1] INFO - Incoming request: GET /api/process-data
...
2025-11-10 10:30:03.000 [http-nio-8080-exec-20] [uuid-20] INFO - Incoming request: GET /api/process-data
2025-11-10 10:30:05.000 [pool-monitor] WARN - ⚠️  THREAD POOL EXHAUSTED! Active: 20/20 (100%) [ALL THREADS BUSY]
```

---

## 📊 Monitoring

### Automated Thread Pool Monitoring

The application logs thread pool status **every 30 seconds**:

```log
# Healthy state
2025-11-10 10:30:00.000 [pool-monitor] INFO - Thread Pool Status: Active: 2/20 (10%) [HEALTHY]

# Moderate load
2025-11-10 10:30:30.000 [pool-monitor] INFO - Thread Pool Status: Active: 12/20 (60%) [MODERATE LOAD]

# High load
2025-11-10 10:31:00.000 [pool-monitor] WARN - Thread Pool Status: Active: 18/20 (90%) [HIGH LOAD]

# Exhausted!
2025-11-10 10:31:30.000 [pool-monitor] WARN - ⚠️  THREAD POOL EXHAUSTED! Active: 20/20 (100%) [ALL THREADS BUSY]
```

### Request ID Tracing

Every request gets a unique ID that appears in all logs:

```bash
# Send request with custom ID
curl -H "X-Request-ID: my-test-123" http://localhost:8080/api/process-data

# Filter logs by request ID
grep "my-test-123" logs/serviceconsumer.log
```

**Example:**
```log
2025-11-10 10:30:45.123 [http-nio-8080-exec-1] [my-test-123] INFO - Incoming request: GET /api/process-data
2025-11-10 10:30:45.125 [http-nio-8080-exec-1] [my-test-123] DEBUG - Calling SlowDependency
2025-11-10 10:30:48.130 [http-nio-8080-exec-1] [my-test-123] ERROR - SlowDependency call failed
```

---

## 🔧 Configuration

Key configuration in `application.properties`:

```properties
# Thread Pool
server.tomcat.threads.max=20
server.tomcat.threads.min-spare=10

# HTTP Client Timeouts
http.client.connect-timeout=2000
http.client.read-timeout=3000

# Dependency URL
dependency.service.url=http://localhost:8081/api/data

# Logging
logging.file.name=logs/serviceconsumer.log
logging.file.max-size=50MB
logging.file.total-size-cap=250MB
```

---

## 📝 Key Takeaways

1. **Thread Pool Starvation is Real**: When all threads are blocked, the entire application stops responding

2. **Cascading Failures**: A failure in one dependency can make the entire application unreachable

3. **Independent Endpoints Affected**: Even `/api/health` (with NO external dependencies) becomes unreachable

4. **Timeouts Are Not Enough**: While timeouts eventually free threads, they don't prevent starvation under sustained load

5. **Solutions** (not implemented here, but worth discussing):
   - Circuit Breakers (Hystrix, Resilience4j)
   - Bulkheads (isolated thread pools)
   - Async/non-blocking clients (WebClient)
   - Rate limiting
   - Back pressure

---

## 🐛 Troubleshooting

### Application won't start
- Check Java version: `java -version` (should be 8+)
- Check port 8080 is available: `lsof -i :8080`

### Can't connect to SlowDependency
- Ensure SlowDependency is running on port 8081
- Check URL in `application.properties`

### Thread dump not showing useful info
- Use during active load (when threads are blocked)
- Look for threads with `RestTemplate` or `SocketInputStream` in stack traces

---

## 📦 Building for Production

```bash
# Clean build
mvn clean package

# Run with production settings (if needed)
java -jar target/service-consumer-1.0.0.jar
```

---

## 👥 Authors

Built to demonstrate thread pool starvation and cascading failures in microservices.

---

## 📄 License

This is a demonstration application for educational purposes.
