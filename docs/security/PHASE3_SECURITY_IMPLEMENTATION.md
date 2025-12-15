# Phase 3: Security Hardening - Implementation Guide

## Overview

Phase 3 completes the security hardening of the DhakaCart e-commerce platform. This phase implements:
- HTTPS/TLS with Let's Encrypt
- Rate limiting (DDoS protection)
- JWT authentication
- Input validation and sanitization
- CORS hardening
- RBAC and Pod Security

## Implementation Summary

### 1. HTTPS/TLS with Let's Encrypt ✅

**Files Created:**
- `k8s/cert-manager.yaml` - cert-manager ClusterIssuer, nginx ingress controller, HTTPS security config
- `k8s/ingress.yaml` - Updated Ingress with TLS certificate configuration

**Installation Steps:**

```bash
# 1. Install cert-manager (if not already installed)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 2. Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# 3. Deploy ClusterIssuer and nginx ingress
kubectl apply -f k8s/cert-manager.yaml

# 4. Deploy updated Ingress with TLS
kubectl apply -f k8s/ingress.yaml

# 5. Verify certificate creation (may take a few minutes)
kubectl get certificate -w
kubectl describe certificate dhakacart-tls

# 6. Test HTTPS endpoint (after DNS is configured)
curl -v https://dhakacart.example.com
```

**Features:**
- Automatic certificate provisioning from Let's Encrypt
- Certificate auto-renewal (30 days before expiry)
- nginx ingress with SSL/TLS 1.2 and 1.3
- Strong cipher suites
- HSTS (HTTP Strict Transport Security) enabled
- Automatic HTTP→HTTPS redirect

**Verification:**
```bash
# Check certificate details
kubectl get secret dhakacart-tls -o yaml

# Check certificate expiration
kubectl get certificate dhakacart-tls -o jsonpath='{.status.notAfter}'

# Verify HSTS header
curl -I https://dhakacart.example.com | grep -i "strict-transport"

# Check TLS version
curl --tlsv1.2 -v https://dhakacart.example.com 2>&1 | grep "TLS"
```

### 2. Rate Limiting ✅

**Files Modified:**
- `backend/server.js` - Added express-rate-limit middleware
- `backend/package.json` - Added express-rate-limit dependency

**Configuration:**

```javascript
// Global rate limiter: 100 requests per 15 minutes per IP
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  skip: (req) => req.path === '/health' || req.path === '/ready'
});

// Strict limiter for login: 5 attempts per 15 minutes per IP
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true // only count failed attempts
});
```

**Features:**
- Global rate limiting (100 req/15 min per IP)
- Strict rate limiting on login endpoint (5 attempts/15 min)
- Health checks excluded from rate limiting
- RateLimit headers in responses
- Prevents brute force attacks
- Prevents DDoS attacks

**Testing:**
```bash
# Test rate limiting
for i in {1..105}; do
  curl -i http://localhost:5000/api/products 2>/dev/null | head -1
done

# Should see "429 Too Many Requests" after 100 requests
```

### 3. JWT Authentication ✅

**Files Modified:**
- `backend/server.js` - Added JWT middleware, login endpoint, protected routes
- `backend/package.json` - Added jsonwebtoken dependency

**Endpoints:**

```javascript
// POST /api/auth/login - Get JWT token
// Request: {"username":"admin","password":"Secure123!"}
// Response: {"token":"eyJhbGc...","expiresIn":"24h"}

// GET /api/protected - Protected endpoint example
// Header: Authorization: Bearer <token>
// Response: Protected data
```

**Features:**
- 24-hour token expiration
- Token validation on protected endpoints
- Demo credentials: admin / Secure123!
- Proper error messages for expired/invalid tokens

**Testing:**
```bash
# 1. Login to get token
TOKEN=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Secure123!"}' | jq -r '.token')

# 2. Use token to access protected endpoint
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/protected

# 3. Test with invalid token
curl -H "Authorization: Bearer invalid.token" http://localhost:5000/api/protected
# Should return 401 Unauthorized
```

### 4. Input Validation & Sanitization ✅

**Files Modified:**
- `backend/server.js` - Added express-validator rules
- `backend/package.json` - Added express-validator dependency

**Validation Rules:**

```javascript
// Username validation
- Required field
- Length: 3-20 characters
- Allowed: alphanumeric and underscores only
- Escaped to prevent XSS

// Password validation
- Required field
- Minimum 8 characters
- No character restrictions (allow special chars)

// Query parameters
- Automatically escaped
- Type checked (integers for limits)
```

**Features:**
- Prevents SQL injection
- Prevents XSS attacks
- Validates all user inputs
- Returns descriptive error messages
- Input sanitization (escaping)

**Testing:**
```bash
# Test invalid username (too short)
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"ab","password":"Secure123!"}'
# Returns 400: Username must be between 3 and 20 characters

# Test special characters
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@#$","password":"Secure123!"}'
# Returns 400: Username can only contain letters, numbers, and underscores

# Test missing password
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin"}'
# Returns 400: Password is required
```

### 5. CORS Hardening ✅

**Files Modified:**
- `backend/server.js` - Restrictive CORS configuration

**Configuration:**

```javascript
// Only allow specific origins
const allowedOrigins = [
  'https://dhakacart.example.com',
  'https://www.dhakacart.example.com',
  'http://localhost:3000'  // for development
];

// Allow specific methods and headers
const corsOptions = {
  origin: allowedOrigins,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400 // 24 hours
};
```

**Features:**
- Whitelist-based CORS
- Specific methods allowed
- Authorization header support
- Credentials allowed (for cookies)
- CORS pre-flight caching (24 hours)

**Testing:**
```bash
# Test allowed origin
curl -H "Origin: https://dhakacart.example.com" \
  -H "Access-Control-Request-Method: GET" \
  -X OPTIONS http://localhost:5000/api/products -v

# Test disallowed origin
curl -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  -X OPTIONS http://localhost:5000/api/products -v
# Should return 403 CORS Error
```

### 6. RBAC and Pod Security ✅

**Files Created:**
- `k8s/rbac.yaml` - ServiceAccounts, Roles, RoleBindings

**Configuration:**

```yaml
# Backend ServiceAccount with read-only permissions
# Allows: read ConfigMaps, Secrets, Pods, Services

# Frontend ServiceAccount with read-only permissions  
# Allows: read ConfigMaps, Services

# Admin ClusterRole for operators
# Allows: manage deployments, services, ingress, configmaps
```

**Installation:**
```bash
# Apply RBAC configuration
kubectl apply -f k8s/rbac.yaml

# Verify ServiceAccounts
kubectl get serviceaccount
kubectl get rolebinding
kubectl get clusterrolebinding

# Test pod permissions
kubectl exec -it <pod-name> -- kubectl auth can-i get pods
kubectl exec -it <pod-name> -- kubectl auth can-i get secrets
```

**Features:**
- Least privilege principle
- Separate accounts for frontend/backend
- Read-only permissions for applications
- Admin role for operators
- Prevents privilege escalation

### 7. Configuration & Secrets ✅

**Files Created:**
- `k8s/config-secrets.yaml` - ConfigMaps and Secrets templates

**Usage:**

```bash
# Apply configuration (ConfigMap only, not secrets)
kubectl apply -f k8s/config-secrets.yaml

# Create/update secrets from environment variables
kubectl set env deployment/dhakacart-backend \
  JWT_SECRET="your-super-secret-key" \
  DB_PASSWORD="your-db-password"

# Or use AWS Secrets Manager (recommended)
aws secretsmanager create-secret \
  --name dhakacart/jwt-secret \
  --secret-string 'your-super-secret-key'
```

## Security Testing

A comprehensive security testing suite is provided:

**File:** `security-test.sh`

**Features:**
- Input validation testing
- Rate limiting verification
- JWT authentication testing
- CORS configuration validation
- Public/protected endpoint testing
- 404 error handling
- Detailed test results logging

**Usage:**

```bash
# Run all tests against local API
./security-test.sh http://localhost:5000 admin Secure123!

# Run against production API
./security-test.sh https://dhakacart.example.com admin your-password

# View results
cat security-test-results.log
```

## Deployment Checklist

Before deploying Phase 3 to production:

- [ ] Update `backend/server.js` with production database credentials
- [ ] Change JWT_SECRET in `k8s/config-secrets.yaml` to a strong random string
- [ ] Update ALLOWED_ORIGINS with actual domain names
- [ ] Deploy cert-manager: `kubectl apply -f k8s/cert-manager.yaml`
- [ ] Wait for cert-manager to be ready
- [ ] Deploy Ingress with TLS: `kubectl apply -f k8s/ingress.yaml`
- [ ] Apply RBAC: `kubectl apply -f k8s/rbac.yaml`
- [ ] Apply configuration: `kubectl apply -f k8s/config-secrets.yaml`
- [ ] Update backend and frontend deployments with ServiceAccountNames
- [ ] Rebuild Docker images with new backend code
- [ ] Deploy updated images to Kubernetes
- [ ] Run security tests: `./security-test.sh https://dhakacart.example.com`
- [ ] Verify certificates were issued: `kubectl get certificate`
- [ ] Check HTTPS endpoint: `curl -v https://dhakacart.example.com`
- [ ] Monitor logs for any security-related errors
- [ ] Document any configuration changes

## Environment Variables

**For Backend Deployment:**

```bash
NODE_ENV=production
JWT_SECRET=your-super-secret-key-change-in-production
DB_HOST=rds-endpoint.amazonaws.com
DB_PORT=5432
DB_NAME=dhakacart
DB_USER=dhakacart_user
DB_PASSWORD=your-secure-password
ALLOWED_ORIGINS=https://dhakacart.example.com,https://www.dhakacart.example.com
LOG_LEVEL=info
```

**For Kubernetes Secrets:**

```bash
kubectl create secret generic dhakacart-secrets \
  --from-literal=JWT_SECRET='your-super-secret-key' \
  --from-literal=DB_PASSWORD='your-secure-password'
```

## Monitoring & Alerting

Monitor these security metrics:

1. **Rate Limit Hits** - Indicates potential DDoS or bot activity
2. **Failed Login Attempts** - Indicates brute force attempts
3. **Invalid Token Errors** - Indicates authentication issues
4. **CORS Errors** - Indicates cross-origin requests from unknown origins
5. **Input Validation Failures** - Indicates malicious input attempts
6. **Certificate Expiration** - Monitor with alert 30 days before expiry

**Prometheus Queries:**

```promql
# Rate of failed logins
rate(failed_login_attempts[5m])

# Rate limit hits
rate(rate_limit_exceeded[5m])

# Certificate expiration (in days)
(cert_manager_certificate_expiration_timestamp_seconds - time()) / 86400
```

## Troubleshooting

### Certificate not issuing
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check ClusterIssuer status
kubectl describe clusterissuer letsencrypt-prod

# Check certificate status
kubectl describe certificate dhakacart-tls

# Common issues:
# 1. DNS not pointing to ingress (wait 10-15 minutes)
# 2. Let's Encrypt rate limits (wait 1 hour)
# 3. Missing ingress controller (deploy nginx ingress first)
```

### Rate limiting not working
```bash
# Verify middleware is loaded
curl -i http://localhost:5000/api/products | grep -i "ratelimit"

# Should see:
# RateLimit-Limit: 100
# RateLimit-Remaining: 99
# RateLimit-Reset: <timestamp>
```

### JWT token issues
```bash
# Verify JWT_SECRET is set
kubectl get secret dhakacart-secrets -o jsonpath='{.data.JWT_SECRET}' | base64 -d

# Check token expiration
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Secure123!"}' | jq '.expiresIn'
```

### CORS errors
```bash
# Verify ALLOWED_ORIGINS
kubectl get configmap dhakacart-config -o jsonpath='{.data.ALLOWED_ORIGINS}'

# Test specific origin
curl -H "Origin: https://your-origin.com" \
  -H "Access-Control-Request-Method: POST" \
  -X OPTIONS http://localhost:5000/api/products -v
```

## Security Best Practices

1. **Secrets Management**
   - Never commit secrets to git
   - Use AWS Secrets Manager or similar
   - Rotate secrets regularly (monthly for passwords, quarterly for API keys)
   - Use strong, random secret values

2. **TLS/HTTPS**
   - Always use HTTPS in production
   - Keep certificates up-to-date
   - Monitor certificate expiration
   - Use TLS 1.2 or higher

3. **Authentication**
   - Use strong password requirements (8+ characters)
   - Implement account lockout after failed attempts
   - Use 2FA/MFA for admin accounts
   - Regularly audit access logs

4. **Authorization**
   - Use least privilege principle
   - Separate permissions by role
   - Regularly review and update RBAC
   - Audit who has access to what

5. **Rate Limiting**
   - Adjust limits based on actual usage patterns
   - Monitor for abuse patterns
   - Implement progressive rate limiting (warn before block)

6. **Input Validation**
   - Validate all user inputs
   - Use allowlist approach (specify what's allowed, not what's blocked)
   - Sanitize all output
   - Log validation failures for monitoring

7. **Infrastructure Security**
   - Use VPC/private networks
   - Restrict security groups to necessary ports
   - Enable CloudTrail for AWS API auditing
   - Use IMDSv2 for EC2 metadata

## Next Steps (Phase 4)

- Run full integration test suite
- Load test for capacity validation
- Backup and restore testing
- Final documentation review
- Prepare presentation with live demo
- Submit to: https://forms.gle/KUrxqhVhxPR2cbMd6

**Deadline: December 15, 2025**

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [express-rate-limit](https://github.com/nfriedly/express-rate-limit)
- [JWT.io](https://jwt.io/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
