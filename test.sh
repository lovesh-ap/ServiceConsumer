#!/bin/bash

################################################################################
# Quick Test Script for ServiceConsumer
# 
# Simple script to quickly verify the application is working
################################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

URL="http://localhost:8090"

echo -e "${BLUE}Testing ServiceConsumer...${NC}\n"

# Test health endpoint
echo "1. Testing /api/health"
response=$(curl -s -w "\n%{http_code}" "$URL/api/health")
http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Health endpoint works${NC}"
    echo "$body" | jq . 2>/dev/null || echo "$body"
else
    echo -e "${RED}✗ Health endpoint failed (HTTP $http_code)${NC}"
fi

echo ""

# Test process-data endpoint
echo "2. Testing /api/process-data"
response=$(curl -s -w "\n%{http_code}" "$URL/api/process-data")
http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Process-data endpoint works${NC}"
    echo "$body" | jq . 2>/dev/null || echo "$body"
elif [ "$http_code" -eq 500 ] || [ "$http_code" -eq 504 ]; then
    echo -e "${RED}✗ Process-data failed (HTTP $http_code) - Is SlowDependency running?${NC}"
    echo "$body" | jq . 2>/dev/null || echo "$body"
else
    echo -e "${RED}✗ Process-data failed (HTTP $http_code)${NC}"
fi

echo ""

# Test metrics endpoint
echo "3. Testing /api/metrics"
response=$(curl -s -w "\n%{http_code}" "$URL/api/metrics")
http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Metrics endpoint works${NC}"
    echo "$body" | jq . 2>/dev/null || echo "$body"
else
    echo -e "${RED}✗ Metrics endpoint failed (HTTP $http_code)${NC}"
fi

echo ""

# Test actuator health
echo "4. Testing /actuator/health"
response=$(curl -s -w "\n%{http_code}" "$URL/actuator/health")
http_code=$(echo "$response" | tail -1)

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Actuator health endpoint works${NC}"
else
    echo -e "${RED}✗ Actuator health failed (HTTP $http_code)${NC}"
fi

echo ""

# Test actuator metrics
echo "5. Testing /actuator/metrics/http.server.requests"
response=$(curl -s -w "\n%{http_code}" "$URL/actuator/metrics/http.server.requests")
http_code=$(echo "$response" | tail -1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✓ Actuator HTTP server requests metrics work${NC}"
    
    if command -v jq &> /dev/null; then
        busy=$(echo "$body" | jq -r '.measurements[0].value')
        echo "  Current busy threads: $busy"
    fi
else
    echo -e "${RED}✗ Actuator metrics failed (HTTP $http_code)${NC}"
fi

echo ""
echo -e "${BLUE}Testing complete!${NC}"
