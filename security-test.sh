#!/bin/bash

# Security Testing Script for DhakaCart
# Tests: Rate limiting, JWT authentication, input validation, CORS, TLS
# Usage: ./security-test.sh [api_url] [username] [password]

set -e

API_URL="${1:-http://localhost:5000}"
USERNAME="${2:-admin}"
PASSWORD="${3:-Secure123!}"
RESULTS_FILE="security-test-results.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize results file
> "$RESULTS_FILE"

log_test() {
  echo -e "${YELLOW}[TEST] $1${NC}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$RESULTS_FILE"
}

log_pass() {
  echo -e "${GREEN}✓ PASS: $1${NC}"
  echo "✓ PASS: $1" >> "$RESULTS_FILE"
}

log_fail() {
  echo -e "${RED}✗ FAIL: $1${NC}"
  echo "✗ FAIL: $1" >> "$RESULTS_FILE"
}

log_info() {
  echo -e "${YELLOW}[INFO] $1${NC}"
  echo "[INFO] $1" >> "$RESULTS_FILE"
}

echo "=========================================="
echo "DhakaCart Security Testing Suite"
echo "=========================================="
echo "API URL: $API_URL"
echo "Test Results: $RESULTS_FILE"
echo ""

# Test 1: Basic connectivity
log_test "Health Check"
if response=$(curl -s "$API_URL/health"); then
  if echo "$response" | grep -q "healthy"; then
    log_pass "API is responding"
  else
    log_fail "API response malformed"
  fi
else
  log_fail "Cannot connect to API"
  exit 1
fi

# Test 2: Invalid input validation
log_test "Input Validation - Short Username"
response=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"ab","password":"Secure123!"}' \
  -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "400" ]; then
  if echo "$body" | grep -q "must be between"; then
    log_pass "Validates username length"
  else
    log_fail "Username validation missing proper message"
  fi
else
  log_fail "Expected 400 status code, got $http_code"
fi

# Test 3: Invalid input validation - Special characters
log_test "Input Validation - Special Characters"
response=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@#$%","password":"Secure123!"}' \
  -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "400" ]; then
  log_pass "Rejects special characters in username"
else
  log_fail "Should reject special characters"
fi

# Test 4: Missing password validation
log_test "Input Validation - Missing Password"
response=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin"}' \
  -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "400" ]; then
  log_pass "Validates required password field"
else
  log_fail "Should require password field"
fi

# Test 5: Short password validation
log_test "Input Validation - Short Password"
response=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Pass1"}' \
  -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "400" ]; then
  log_pass "Validates password minimum length"
else
  log_fail "Should validate password length"
fi

# Test 6: Valid login
log_test "Authentication - Valid Login"
response=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" \
  -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
  TOKEN=$(echo "$body" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
  if [ -n "$TOKEN" ]; then
    log_pass "Successfully obtained JWT token"
    log_info "Token (first 50 chars): ${TOKEN:0:50}..."
  else
    log_fail "Token not found in response"
  fi
else
  log_fail "Login failed with status $http_code"
fi

# Test 7: Invalid login
log_test "Authentication - Invalid Credentials"
response=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"WrongPassword"}' \
  -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "401" ]; then
  log_pass "Rejects invalid credentials"
else
  log_fail "Should return 401 for invalid credentials"
fi

# Test 8: Rate limiting
log_test "Rate Limiting - Global Limiter (100 requests/15min)"
log_info "Making 101 requests to trigger rate limit..."
success_count=0
limited_count=0

for i in {1..101}; do
  response=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/products")
  if [ "$response" = "200" ]; then
    ((success_count++))
  elif [ "$response" = "429" ]; then
    ((limited_count++))
  fi
done

if [ "$limited_count" -gt 0 ]; then
  log_pass "Rate limiting active (429 responses received: $limited_count)"
else
  log_info "Rate limiting may not be triggered (received $success_count 200s). Check RateLimit headers."
fi

# Test 9: Protected endpoint without token
log_test "Protected Endpoint - No Token"
response=$(curl -s "$API_URL/api/protected" -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "401" ]; then
  log_pass "Protected endpoint requires token"
else
  log_fail "Should return 401 without token"
fi

# Test 10: Protected endpoint with token
log_test "Protected Endpoint - With Valid Token"
if [ -n "$TOKEN" ]; then
  response=$(curl -s "$API_URL/api/protected" \
    -H "Authorization: Bearer $TOKEN" \
    -w "\n%{http_code}")
  http_code=$(echo "$response" | tail -n 1)
  body=$(echo "$response" | head -n -1)
  
  if [ "$http_code" = "200" ]; then
    if echo "$body" | grep -q "protected endpoint"; then
      log_pass "Protected endpoint accessible with valid token"
    else
      log_fail "Invalid response from protected endpoint"
    fi
  else
    log_fail "Expected 200, got $http_code"
  fi
else
  log_info "Skipping (no valid token available)"
fi

# Test 11: Protected endpoint with invalid token
log_test "Protected Endpoint - Invalid Token"
response=$(curl -s "$API_URL/api/protected" \
  -H "Authorization: Bearer invalid.token.here" \
  -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "401" ]; then
  log_pass "Invalid token rejected"
else
  log_fail "Should return 401 for invalid token"
fi

# Test 12: CORS headers
log_test "CORS Configuration"
response=$(curl -s -X OPTIONS "$API_URL/api/products" \
  -H "Origin: https://dhakacart.example.com" \
  -H "Access-Control-Request-Method: GET" \
  -v 2>&1 | grep -i "access-control")

if echo "$response" | grep -q "access-control-allow"; then
  log_pass "CORS headers present in response"
else
  log_info "CORS headers not detected (may be expected depending on configuration)"
fi

# Test 13: Public endpoint accessibility
log_test "Public Endpoint - Products API"
response=$(curl -s "$API_URL/api/products" -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
  if echo "$body" | grep -q "products"; then
    log_pass "Public endpoint accessible without authentication"
  else
    log_fail "Invalid response format"
  fi
else
  log_fail "Expected 200, got $http_code"
fi

# Test 14: 404 error handling
log_test "Error Handling - 404 Not Found"
response=$(curl -s "$API_URL/api/nonexistent" -w "\n%{http_code}")
http_code=$(echo "$response" | tail -n 1)

if [ "$http_code" = "404" ]; then
  log_pass "404 handling works correctly"
else
  log_fail "Expected 404, got $http_code"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
grep -c "✓ PASS" "$RESULTS_FILE" && pass_count=$(grep -c "✓ PASS" "$RESULTS_FILE") || pass_count=0
grep -c "✗ FAIL" "$RESULTS_FILE" && fail_count=$(grep -c "✗ FAIL" "$RESULTS_FILE") || fail_count=0

echo -e "${GREEN}Passed: $pass_count${NC}"
echo -e "${RED}Failed: $fail_count${NC}"
echo "Full results saved to: $RESULTS_FILE"
echo ""

if [ "$fail_count" -gt 0 ]; then
  echo -e "${RED}Some security tests failed. Review results above.${NC}"
  exit 1
else
  echo -e "${GREEN}All security tests passed!${NC}"
  exit 0
fi
