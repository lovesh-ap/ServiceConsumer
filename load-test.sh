#!/bin/bash

################################################################################
# Load Test Script for ServiceConsumer
# 
# Simulates the thread pool exhaustion scenario
# 
# Usage:
#   ./load-test.sh                           # One-time load test with 50 requests
#   ./load-test.sh 100                       # One-time load test with 100 requests
#   ./load-test.sh 50 5                      # Continuous: 50 requests every 5 seconds
#   ./load-test.sh 30 10 forever            # Continuous: 30 requests every 10 seconds (forever)
################################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
URL="http://localhost:8080"
CONCURRENT_REQUESTS=${1:-50}        # Default 50, or use first argument
INTERVAL=${2:-0}                     # Default 0 (one-time), or use second argument
MODE=${3:-once}                      # Default 'once', or 'forever'

# Statistics
TOTAL_BATCHES=0
TOTAL_REQUESTS=0
START_TIME=$(date +%s)

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

run_load_batch() {
    local batch_num=$1
    local timestamp=$(get_timestamp)
    
    echo ""
    echo -e "${BLUE}[${timestamp}] Batch #${batch_num}: Launching ${CONCURRENT_REQUESTS} concurrent requests...${NC}"
    
    # Launch concurrent requests
    local batch_start=$(date +%s)
    
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        {
            curl -s -o /dev/null "$URL/api/process-data" 2>/dev/null
        } &
    done
    
    echo -e "${GREEN}✓ Batch #${batch_num}: ${CONCURRENT_REQUESTS} requests sent${NC}"
    
    # Update statistics
    TOTAL_BATCHES=$((TOTAL_BATCHES + 1))
    TOTAL_REQUESTS=$((TOTAL_REQUESTS + CONCURRENT_REQUESTS))
}

check_thread_pool() {
    local response=$(curl -s "$URL/api/metrics" 2>/dev/null)
    
    if command -v jq &> /dev/null; then
        local active=$(echo "$response" | jq -r '.threadPool.activeThreads' 2>/dev/null)
        local max=$(echo "$response" | jq -r '.threadPool.maxThreads' 2>/dev/null)
        local exhausted=$(echo "$response" | jq -r '.threadPool.exhausted' 2>/dev/null)
        
        if [ "$exhausted" = "true" ]; then
            echo -e "${RED}  Thread Pool: ${active}/${max} (EXHAUSTED!)${NC}"
        elif [ $active -ge $((max * 80 / 100)) ]; then
            echo -e "${YELLOW}  Thread Pool: ${active}/${max} (High Load)${NC}"
        else
            echo -e "${GREEN}  Thread Pool: ${active}/${max} (Healthy)${NC}"
        fi
    fi
}

print_statistics() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local avg_requests_per_sec=$((TOTAL_REQUESTS / (elapsed > 0 ? elapsed : 1)))
    
    echo ""
    echo -e "${CYAN}Statistics:${NC}"
    echo -e "  Batches sent: ${TOTAL_BATCHES}"
    echo -e "  Total requests: ${TOTAL_REQUESTS}"
    echo -e "  Running time: ${elapsed}s"
    echo -e "  Avg requests/sec: ${avg_requests_per_sec}"
}

cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping load test...${NC}"
    print_statistics
    echo ""
    echo -e "${BLUE}Waiting for background processes to complete...${NC}"
    wait
    echo -e "${GREEN}✓ All background processes completed${NC}"
    echo ""
    exit 0
}

# Trap Ctrl+C for graceful shutdown
trap cleanup SIGINT SIGTERM

################################################################################
# Main Script
################################################################################

clear
print_header "Load Test: Thread Pool Exhaustion"
echo ""
echo "Configuration:"
echo "  URL: $URL/api/process-data"
echo "  Concurrent Requests: $CONCURRENT_REQUESTS"

if [ "$INTERVAL" -gt 0 ]; then
    echo "  Mode: CONTINUOUS (every ${INTERVAL} seconds)"
    if [ "$MODE" = "forever" ]; then
        echo "  Duration: Forever (Ctrl+C to stop)"
    else
        echo "  Duration: Until manually stopped (Ctrl+C)"
    fi
else
    echo "  Mode: ONE-TIME"
fi

echo ""
echo -e "${YELLOW}IMPORTANT: Make sure SlowDependency is in 'hang' mode!${NC}"
echo ""
echo "Press ENTER to start the load test..."
read

echo ""
echo -e "${BLUE}Step 1: Checking baseline thread pool status...${NC}"
check_thread_pool
echo ""

if [ "$INTERVAL" -gt 0 ]; then
    # CONTINUOUS MODE
    print_header "Starting Continuous Load Test"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop the load test${NC}"
    echo ""
    
    batch_count=1
    
    while true; do
        run_load_batch $batch_count
        check_thread_pool
        
        # Show statistics every 10 batches
        if [ $((batch_count % 10)) -eq 0 ]; then
            print_statistics
        fi
        
        batch_count=$((batch_count + 1))
        
        # Sleep for the specified interval
        sleep $INTERVAL
    done
else
    # ONE-TIME MODE (original behavior)
    echo -e "${BLUE}Step 2: Launching $CONCURRENT_REQUESTS concurrent requests...${NC}"
    echo ""
    
    # Launch concurrent requests
    start_time=$(date +%s)
    
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        {
            response_time=$(curl -s -w "%{time_total}\n" -o /dev/null "$URL/api/process-data")
            echo "Request $i completed in $response_time seconds"
        } &
    done
    
    echo -e "${GREEN}All $CONCURRENT_REQUESTS requests launched in background${NC}"
    echo ""
    
    # Wait a moment for threads to get blocked
    sleep 2
    
    echo -e "${BLUE}Step 3: Checking thread pool during load...${NC}"
    check_thread_pool
    echo ""
    
    echo -e "${BLUE}Step 4: Testing /api/health endpoint (should hang!)...${NC}"
    echo "Trying to call /api/health with 10-second timeout..."
    echo ""
    
    health_start=$(date +%s)
    if timeout 10 curl -s "$URL/api/health" > /dev/null 2>&1; then
        health_end=$(date +%s)
        health_duration=$((health_end - health_start))
        echo -e "${YELLOW}⚠ Health endpoint responded in ${health_duration}s (some threads available)${NC}"
    else
        echo -e "${RED}✗ Health endpoint TIMED OUT - Thread pool is EXHAUSTED!${NC}"
    fi
    echo ""
    
    echo -e "${BLUE}Step 5: Getting thread dump...${NC}"
    thread_dump_file="thread-dump-$(date +%s).json"
    curl -s "$URL/actuator/threaddump" > "$thread_dump_file"
    echo "Thread dump saved to: $thread_dump_file"
    
    if command -v jq &> /dev/null; then
        http_threads=$(jq '[.threads[] | select(.threadName | startswith("http-nio"))] | length' "$thread_dump_file")
        echo "HTTP worker threads found: $http_threads"
    fi
    echo ""
    
    echo -e "${BLUE}Step 6: Waiting for all requests to complete...${NC}"
    wait
    
    end_time=$(date +%s)
    total_time=$((end_time - start_time))
    
    echo ""
    echo -e "${GREEN}All requests completed in ${total_time} seconds${NC}"
    echo ""
    
    echo -e "${BLUE}Step 7: Checking thread pool after load...${NC}"
    check_thread_pool
    echo ""
    
    echo -e "${BLUE}Step 8: Testing /api/health after recovery...${NC}"
    if curl -s "$URL/api/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Health endpoint is accessible again${NC}"
    else
        echo -e "${RED}✗ Health endpoint still unavailable${NC}"
    fi
    
    echo ""
    print_header "Load Test Complete"
    echo ""
    echo "Summary:"
    echo "  • Sent $CONCURRENT_REQUESTS concurrent requests"
    echo "  • Total execution time: ${total_time}s"
    echo "  • Thread dump saved to: $thread_dump_file"
    echo ""
    echo "Check the logs at: logs/serviceconsumer.log"
    echo "Look for thread pool exhaustion warnings!"
    echo ""
fi
