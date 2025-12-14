#!/bin/bash
# Debug version of integration tests

echo "Debug: Testing Frontend Homepage..."
curl -s -w "HTTP Code: %{http_code}\n" http://localhost:8080/

echo ""
echo "Debug: Testing Frontend 404..."
curl -s -w "HTTP Code: %{http_code}\n" http://localhost:8080/nonexistent

echo ""
echo "Debug: Testing Backend Health..."
curl -s -w "HTTP Code: %{http_code}\n" http://localhost:5000/health

echo ""
echo "Debug: Testing Backend Ready..."
curl -s -w "HTTP Code: %{http_code}\n" http://localhost:5000/ready

echo ""
echo "Debug: Testing Backend Main..."
curl -s http://localhost:5000/

echo ""
echo "Debug: Testing Backend Products..."
curl -s http://localhost:5000/api/products

echo ""
echo "Debug: Testing Backend 404..."
curl -s -w "HTTP Code: %{http_code}\n" http://localhost:5000/nonexistent
