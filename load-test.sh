#!/bin/bash
# Load testing script for DhakaCart using Apache Bench
# Usage: ./load-test.sh <target-url> <number-of-requests> <concurrent-users>

set -e

TARGET_URL="${1:-http://localhost:8080}"
REQUESTS="${2:-10000}"
CONCURRENCY="${3:-100}"
RESULTS_DIR="./load-test-results"

# Create results directory
mkdir -p "$RESULTS_DIR"

echo "=================================================="
echo "DhakaCart Load Testing Script"
echo "=================================================="
echo "Target URL: $TARGET_URL"
echo "Total Requests: $REQUESTS"
echo "Concurrent Users: $CONCURRENCY"
echo "=================================================="
echo ""

# Check if Apache Bench is installed
if ! command -v ab &> /dev/null; then
    echo "❌ Apache Bench (ab) is not installed"
    echo "Install it with: sudo apt-get install apache2-utils"
    exit 1
fi

# Test 1: Frontend homepage
echo "📊 Test 1: Frontend Homepage"
ab -n "$REQUESTS" -c "$CONCURRENCY" -g "$RESULTS_DIR/homepage.txt" "$TARGET_URL/" > "$RESULTS_DIR/homepage-results.txt" 2>&1
echo "✅ Results saved to $RESULTS_DIR/homepage-results.txt"
echo ""

# Test 2: Backend API health check
echo "📊 Test 2: Backend Health Check"
BACKEND_URL="${TARGET_URL%:*}:5000"
ab -n "$REQUESTS" -c "$CONCURRENCY" -g "$RESULTS_DIR/health.txt" "$BACKEND_URL/health" > "$RESULTS_DIR/health-results.txt" 2>&1
echo "✅ Results saved to $RESULTS_DIR/health-results.txt"
echo ""

# Test 3: Backend API main endpoint
echo "📊 Test 3: Backend API Endpoint"
ab -n "$REQUESTS" -c "$CONCURRENCY" -g "$RESULTS_DIR/api.txt" "$BACKEND_URL/" > "$RESULTS_DIR/api-results.txt" 2>&1
echo "✅ Results saved to $RESULTS_DIR/api-results.txt"
echo ""

# Test 4: Products API endpoint
echo "📊 Test 4: Products API Endpoint"
ab -n "$REQUESTS" -c "$CONCURRENCY" -g "$RESULTS_DIR/products.txt" "$BACKEND_URL/api/products" > "$RESULTS_DIR/products-results.txt" 2>&1
echo "✅ Results saved to $RESULTS_DIR/products-results.txt"
echo ""

# Generate summary
echo "=================================================="
echo "📈 Load Test Summary"
echo "=================================================="

for file in "$RESULTS_DIR"/*-results.txt; do
    filename=$(basename "$file")
    echo ""
    echo "--- $filename ---"
    grep -E "Requests per second|Time per request|Failed requests|Percentage of requests" "$file" || true
done

echo ""
echo "=================================================="
echo "✅ Load testing complete!"
echo "Results saved in: $RESULTS_DIR/"
echo "=================================================="
