#!/bin/bash

################################################################################
# Load Test Script for ServiceConsumer
# 
# Simulates the thread pool exhaustion scenario
################################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

URL="http://localhost:8080"
CONCURRENT_REQUESTS=${1:-50}  # Default 50, or use first argument

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Load Test: Thread Pool Exhaustion${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Concurrent Requests: $CONCURRENT_REQUESTS"
echo "Target: $URL/api/process-data"
echo ""
echo -e "${YELLOW}IMPORTANT: Make sure SlowDependency is in 'hang' mode!${NC}"
echo ""
echo "Press ENTER to start the load test..."
read

echo ""
echo -e "${BLUE}Step 1: Checking baseline thread pool status...${NC}"
curl -s "$URL/api/metrics" | jq '.threadPool' 2>/dev/null || curl -s "$URL/api/metrics"
echo ""

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
curl -s "$URL/api/metrics" | jq '.threadPool' 2>/dev/null || curl -s "$URL/api/metrics"
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
curl -s "$URL/api/metrics" | jq '.threadPool' 2>/dev/null || curl -s "$URL/api/metrics"
echo ""

echo -e "${BLUE}Step 8: Testing /api/health after recovery...${NC}"
if curl -s "$URL/api/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Health endpoint is accessible again${NC}"
else
    echo -e "${RED}✗ Health endpoint still unavailable${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Load Test Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Summary:"
echo "  • Sent $CONCURRENT_REQUESTS concurrent requests"
echo "  • Total execution time: ${total_time}s"
echo "  • Thread dump saved to: $thread_dump_file"
echo ""
echo "Check the logs at: logs/serviceconsumer.log"
echo "Look for thread pool exhaustion warnings!"
echo ""
