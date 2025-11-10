#!/bin/bash

################################################################################
# ServiceConsumer Demo Script
# 
# This script demonstrates thread pool starvation and cascading failures
# 
# Prerequisites:
# 1. ServiceConsumer running on http://localhost:8080
# 2. SlowDependency running on http://localhost:8081
# 3. curl installed
# 4. (optional) jq for pretty JSON output
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SERVICE_CONSUMER_URL="http://localhost:8090"
SLOW_DEPENDENCY_URL="http://localhost:8081"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

wait_for_user() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
}

check_service() {
    local url=$1
    local name=$2
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        print_success "$name is running at $url"
        return 0
    else
        print_error "$name is NOT running at $url"
        return 1
    fi
}

make_request() {
    local url=$1
    local description=$2
    
    echo -e "${BLUE}Request: $description${NC}"
    echo -e "URL: $url"
    
    start_time=$(date +%s%3N)
    response=$(curl -s -w "\n%{http_code}\n%{time_total}" "$url")
    end_time=$(date +%s%3N)
    
    http_code=$(echo "$response" | tail -2 | head -1)
    time_total=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -2)
    
    duration=$((end_time - start_time))
    
    if [ "$http_code" -eq 200 ]; then
        print_success "Response: HTTP $http_code - Duration: ${duration}ms"
    else
        print_warning "Response: HTTP $http_code - Duration: ${duration}ms"
    fi
    
    if command -v jq &> /dev/null; then
        echo "$body" | jq . 2>/dev/null || echo "$body"
    else
        echo "$body"
    fi
    
    echo ""
}

get_thread_pool_stats() {
    response=$(curl -s "$SERVICE_CONSUMER_URL/api/metrics")
    
    if command -v jq &> /dev/null; then
        active=$(echo "$response" | jq -r '.threadPool.activeThreads')
        max=$(echo "$response" | jq -r '.threadPool.maxThreads')
        exhausted=$(echo "$response" | jq -r '.threadPool.exhausted')
        
        echo -e "${BLUE}Thread Pool: $active/$max threads active${NC}"
        
        if [ "$exhausted" = "true" ]; then
            print_warning "Thread pool is EXHAUSTED!"
        fi
    else
        echo "$response"
    fi
}

################################################################################
# Main Demo
################################################################################

clear

print_header "ServiceConsumer Thread Pool Starvation Demo"

echo "This demo will show how a microservice becomes completely unresponsive"
echo "when its dependencies fail, causing thread pool exhaustion."
echo ""
echo "The demo has 3 scenarios:"
echo "  1. Baseline (Everything Healthy)"
echo "  2. Single Request Timeout"
echo "  3. Thread Pool Exhaustion (The Main Demo)"
echo ""

wait_for_user

################################################################################
# Pre-flight Checks
################################################################################

print_header "Pre-flight Checks"

print_step "Checking if ServiceConsumer is running..."
if ! check_service "$SERVICE_CONSUMER_URL/api/health" "ServiceConsumer"; then
    echo ""
    echo "Please start ServiceConsumer first:"
    echo "  cd ServiceConsumer"
    echo "  mvn spring-boot:run"
    exit 1
fi

print_step "Checking if SlowDependency is running..."
if ! check_service "$SLOW_DEPENDENCY_URL/api/data" "SlowDependency"; then
    print_warning "SlowDependency is not running - some demos will fail"
    echo ""
    echo "To start SlowDependency:"
    echo "  cd SlowDependency"
    echo "  mvn spring-boot:run"
    echo ""
    wait_for_user
fi

################################################################################
# Scenario 1: Baseline (Everything Healthy)
################################################################################

print_header "Scenario 1: Baseline (Everything Healthy)"

echo "In this scenario, both services are healthy."
echo "We'll make requests to both endpoints and observe fast response times."
echo ""

wait_for_user

print_step "Step 1.1: Check health endpoint (no external dependencies)"
make_request "$SERVICE_CONSUMER_URL/api/health" "Health Check"

print_step "Step 1.2: Check process-data endpoint (calls SlowDependency)"
make_request "$SERVICE_CONSUMER_URL/api/process-data" "Process Data"

print_step "Step 1.3: Check thread pool status"
get_thread_pool_stats

echo ""
print_success "BASELINE: Both endpoints are fast and responsive"
print_success "Thread pool has plenty of available threads"
echo ""

wait_for_user

################################################################################
# Scenario 2: Single Request Timeout
################################################################################

print_header "Scenario 2: Single Request Timeout"

echo "In this scenario, SlowDependency is slow/unresponsive."
echo "A single request will timeout after 3 seconds, but the app recovers."
echo ""
echo -e "${YELLOW}NOTE: Make sure SlowDependency is in 'hang' mode for this demo${NC}"
echo "If you have a control endpoint, set it to hang mode now."
echo ""

wait_for_user

print_step "Step 2.1: Make a single request to process-data (will timeout)"
print_warning "This will take 3 seconds..."
make_request "$SERVICE_CONSUMER_URL/api/process-data" "Process Data (with timeout)"

print_step "Step 2.2: Check health endpoint immediately after (should still work)"
make_request "$SERVICE_CONSUMER_URL/api/health" "Health Check"

print_step "Step 2.3: Check thread pool status"
get_thread_pool_stats

echo ""
print_success "OBSERVATION: The request timed out after 3 seconds"
print_success "But /api/health still works because threads are available"
echo ""

wait_for_user

################################################################################
# Scenario 3: Thread Pool Exhaustion (THE MAIN DEMO)
################################################################################

print_header "Scenario 3: Thread Pool Exhaustion ⚠️"

echo "This is the main demonstration of thread pool starvation."
echo ""
echo "What will happen:"
echo "  1. We'll send 50 concurrent requests to /api/process-data"
echo "  2. All 20 threads will become blocked waiting for SlowDependency"
echo "  3. The /api/health endpoint will become UNREACHABLE"
echo "  4. The entire application becomes unresponsive"
echo ""
echo -e "${RED}This demonstrates cascading failure!${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Make sure SlowDependency is in 'hang' mode${NC}"
echo ""

wait_for_user

print_step "Step 3.1: Check thread pool before attack"
get_thread_pool_stats
echo ""

print_step "Step 3.2: Sending 50 concurrent requests to /api/process-data"
print_warning "This will flood the thread pool..."
echo ""

# Send 50 concurrent requests in background
echo "Launching 50 requests..."
for i in {1..50}; do
    curl -s "$SERVICE_CONSUMER_URL/api/process-data" > /dev/null &
done

echo -e "${GREEN}50 requests sent in background${NC}"
echo ""
sleep 1

print_step "Step 3.3: Now try to call /api/health (should HANG or timeout)"
print_error "Watch this hang because no threads are available!"
echo ""

# Try to call health endpoint with a timeout
echo "Attempting to call /api/health with 10-second timeout..."
if timeout 10 curl -s "$SERVICE_CONSUMER_URL/api/health" > /dev/null 2>&1; then
    print_warning "Health endpoint responded (some threads may be available)"
else
    print_error "Health endpoint TIMED OUT or HUNG - Thread pool exhausted!"
fi
echo ""

print_step "Step 3.4: Check thread pool status"
get_thread_pool_stats
echo ""

print_step "Step 3.5: Check thread dump from actuator"
echo "Getting thread dump to see blocked threads..."
echo ""
thread_dump=$(curl -s "$SERVICE_CONSUMER_URL/actuator/threaddump")

if command -v jq &> /dev/null; then
    # Count threads in different states
    runnable=$(echo "$thread_dump" | jq '[.threads[] | select(.threadState == "RUNNABLE")] | length')
    waiting=$(echo "$thread_dump" | jq '[.threads[] | select(.threadState == "TIMED_WAITING")] | length')
    
    echo -e "${BLUE}Thread States:${NC}"
    echo "  RUNNABLE: $runnable"
    echo "  TIMED_WAITING: $waiting"
    echo ""
    
    print_warning "Check the full thread dump at $SERVICE_CONSUMER_URL/actuator/threaddump"
    print_warning "You'll see threads blocked in RestTemplate socket reads!"
else
    echo "Thread dump retrieved (use jq to parse or check manually)"
    echo "URL: $SERVICE_CONSUMER_URL/actuator/threaddump"
fi

echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}THREAD POOL EXHAUSTION DEMONSTRATED!${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Key Observations:"
echo "  ✗ All 20 threads are blocked waiting for SlowDependency"
echo "  ✗ /api/health endpoint (with NO dependency) is unreachable"
echo "  ✗ The entire application is unresponsive"
echo "  ✗ This is a CASCADING FAILURE"
echo ""

wait_for_user

print_step "Step 3.6: Wait for recovery..."
echo "Waiting 10 seconds for threads to timeout and recover..."
sleep 10

print_step "Step 3.7: Check if /api/health works now"
make_request "$SERVICE_CONSUMER_URL/api/health" "Health Check (after recovery)"

print_step "Step 3.8: Check thread pool status"
get_thread_pool_stats

echo ""
print_success "Application has recovered as threads became available"
echo ""

################################################################################
# Summary
################################################################################

print_header "Demo Complete - Summary"

echo "What we demonstrated:"
echo ""
echo "1. ${GREEN}Baseline${NC}: Both endpoints work fine when dependencies are healthy"
echo ""
echo "2. ${YELLOW}Single Timeout${NC}: A single request times out but app recovers"
echo ""
echo "3. ${RED}Thread Pool Exhaustion${NC}: Under load, all threads block and the entire"
echo "   application becomes unresponsive, even endpoints with no dependencies!"
echo ""
echo "Key Takeaways:"
echo "  • Thread pool starvation is a real problem in microservices"
echo "  • Cascading failures can make your entire service unreachable"
echo "  • Timeouts alone are not enough protection"
echo ""
echo "Solutions (not implemented here):"
echo "  • Circuit Breakers (Resilience4j, Hystrix)"
echo "  • Bulkheads (isolated thread pools)"
echo "  • Async/non-blocking clients (WebClient)"
echo "  • Rate limiting and back pressure"
echo ""

print_header "Thank you for watching the demo!"
