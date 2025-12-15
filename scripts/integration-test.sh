#!/bin/bash
# Integration and smoke tests for DhakaCart services
# Usage: ./integration-test.sh

set -e

FRONTEND_URL="${FRONTEND_URL:-http://localhost:8080}"
BACKEND_URL="${BACKEND_URL:-http://localhost:5000}"
TESTS_PASSED=0
TESTS_FAILED=0

echo "=================================================="
echo "🧪 DhakaCart Integration Tests"
echo "=================================================="
echo ""

# Function to test endpoint
test_endpoint() {
    local test_name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    
    echo -n "Testing: $test_name ... "
    
    response=$(curl -s -w "\n%{http_code}" "$url")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" -eq "$expected_status" ]; then
        echo "✅ PASS (HTTP $http_code)"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL (Expected $expected_status, got $http_code)"
        echo "Response: $body"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Function to test response contains JSON
test_json_response() {
    local test_name="$1"
    local url="$2"
    local json_key="$3"
    
    echo -n "Testing: $test_name ... "
    
    response=$(curl -s "$url")
    
    if echo "$response" | grep -q "$json_key"; then
        echo "✅ PASS (JSON key found: $json_key)"
        ((TESTS_PASSED++))
        return 0
    else
        echo "❌ FAIL (JSON key not found: $json_key)"
        echo "Response: $response"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "🔗 Frontend Tests"
echo "---"
test_endpoint "Frontend Homepage" "$FRONTEND_URL/" 200
test_endpoint "Frontend 404 Not Found" "$FRONTEND_URL/nonexistent" 404
echo ""

echo "🔗 Backend Tests"
echo "---"
test_endpoint "Backend Health Check" "$BACKEND_URL/health" 200
test_endpoint "Backend Ready Check" "$BACKEND_URL/ready" 200
test_json_response "Backend Main Endpoint" "$BACKEND_URL/" "DhakaCart API"
test_json_response "Backend Products API" "$BACKEND_URL/api/products" "products"
test_endpoint "Backend 404" "$BACKEND_URL/nonexistent" 404
echo ""

echo "🔗 API Response Tests"
echo "---"

# Test API response structure
echo -n "Testing: API response contains status message ... "
response=$(curl -s "$BACKEND_URL/")
if echo "$response" | jq . >/dev/null 2>&1; then
    if echo "$response" | jq -e '.message' >/dev/null; then
        echo "✅ PASS"
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL"
        ((TESTS_FAILED++))
    fi
else
    echo "❌ FAIL (Invalid JSON)"
    ((TESTS_FAILED++))
fi

# Test products endpoint returns array
echo -n "Testing: Products endpoint returns array ... "
response=$(curl -s "$BACKEND_URL/api/products")
if echo "$response" | jq -e '.products | type == "array"' >/dev/null 2>&1; then
    echo "✅ PASS"
    ((TESTS_PASSED++))
else
    echo "❌ FAIL"
    ((TESTS_FAILED++))
fi

echo ""
echo "=================================================="
echo "📊 Test Summary"
echo "=================================================="
echo "✅ Passed: $TESTS_PASSED"
echo "❌ Failed: $TESTS_FAILED"
echo "📈 Total: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed!"
    exit 1
fi
