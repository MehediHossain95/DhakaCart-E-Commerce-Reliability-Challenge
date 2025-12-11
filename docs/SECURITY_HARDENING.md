# Phase 3: Security Hardening - Quick Reference

## 🔐 Remaining Security Tasks

### 1. HTTPS/TLS with Let's Encrypt (1-2 hours)

#### Install cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

#### Create ClusterIssuer for Let's Encrypt
```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@dhakacart.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

#### Update Ingress with TLS
```bash
# Edit k8s/frontend.yaml and update ingress:
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dhakacart-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - dhakacart.example.com
    secretName: dhakacart-tls
  rules:
  - host: dhakacart.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dhakacart-frontend-service
            port:
              number: 80
```

#### Deploy nginx ingress controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.0/deploy/static/provider/cloud/deploy.yaml

# Verify
kubectl get pods -n ingress-nginx
```

---

### 2. Rate Limiting (1 hour)

#### Update backend/server.js
```javascript
const express = require('express');
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const redis = require('redis');

// Create Redis client (optional, for distributed rate limiting)
// const redisClient = redis.createClient();

// Simple rate limiter
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

// Strict rate limiting for login endpoint
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // 5 attempts per 15 minutes
  skipSuccessfulRequests: true,
});

app.use(limiter); // Apply to all routes

// Apply strict limiter to sensitive endpoints
app.post('/api/auth/login', loginLimiter, (req, res) => {
  // Login logic
});
```

#### Update backend/package.json
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "express-rate-limit": "^6.7.0",
    "redis": "^4.6.0",
    "rate-limit-redis": "^3.0.1"
  }
}
```

---

### 3. JWT Authentication (2 hours)

#### Install JWT package
```bash
# Add to backend/package.json
{
  "dependencies": {
    "jsonwebtoken": "^9.0.0"
  }
}
```

#### Create auth middleware
```javascript
// backend/auth.js
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

exports.verifyToken = (req, res, next) => {
  const token = req.headers['authorization']?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    req.userId = decoded.userId;
    next();
  });
};

exports.generateToken = (userId) => {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '24h' });
};
```

#### Create login endpoint
```javascript
// backend/server.js
const auth = require('./auth');

app.post('/api/auth/login', loginLimiter, (req, res) => {
  const { username, password } = req.body;
  
  // TODO: Validate credentials against database
  if (username === 'admin' && password === 'secure-password') {
    const token = auth.generateToken(1);
    return res.json({ token });
  }
  
  res.status(401).json({ error: 'Invalid credentials' });
});

// Protected endpoint example
app.get('/api/protected', auth.verifyToken, (req, res) => {
  res.json({ message: 'This endpoint is protected', userId: req.userId });
});
```

---

### 4. Input Validation & Sanitization (1-2 hours)

#### Install validation package
```bash
# Add to backend/package.json
{
  "dependencies": {
    "express-validator": "^7.0.0"
  }
}
```

#### Add input validation
```javascript
// backend/server.js
const { body, validationResult } = require('express-validator');

// Validation middleware
const validateLogin = [
  body('username')
    .trim()
    .notEmpty().withMessage('Username required')
    .isLength({ min: 3, max: 20 })
    .matches(/^[a-zA-Z0-9_]+$/).withMessage('Invalid username format'),
  body('password')
    .notEmpty().withMessage('Password required')
    .isLength({ min: 8 }).withMessage('Password must be 8+ chars'),
];

// Use validation middleware
app.post('/api/auth/login', loginLimiter, validateLogin, (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  
  const { username, password } = req.body;
  // Process login...
});

// Validate product queries
app.get('/api/products', [
  query('category')
    .optional()
    .trim()
    .escape(),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 }).toInt(),
], (req, res) => {
  // Fetch products with validated parameters
});
```

---

### 5. CORS Configuration (30 minutes)

#### Update backend/server.js
```javascript
const cors = require('cors');

const allowedOrigins = [
  'https://dhakacart.com',
  'https://www.dhakacart.com',
  'https://admin.dhakacart.com'
];

const corsOptions = {
  origin: function(origin, callback) {
    if (allowedOrigins.includes(origin) || !origin) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400, // 24 hours
};

app.use(cors(corsOptions));
```

---

### 6. Secrets Scanning in GitHub (30 minutes)

#### Enable in GitHub
1. Go to repository Settings
2. Code security and analysis
3. Enable "Secret scanning"
4. Enable "Dependabot alerts"
5. Enable "Dependabot security updates"

#### Add pre-commit hook (local)
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Scan for secrets
git diff --cached | grep -E "password|secret|token|key" && {
    echo "❌ Error: Potential secrets detected in commit"
    exit 1
}

exit 0
```

---

### 7. Pod Security Standards (1 hour)

#### Apply restricted PSS
```bash
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
kubectl label namespace default pod-security.kubernetes.io/audit=restricted
kubectl label namespace default pod-security.kubernetes.io/warn=restricted
```

#### Verify pod security
```bash
# Check pod security context
kubectl get pods -o jsonpath='{.items[*].spec.securityContext}'
```

---

### 8. RBAC Configuration (1-2 hours)

#### Create custom roles
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backend-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["app-config"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-reader-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: backend-reader
subjects:
- kind: ServiceAccount
  name: backend-sa
  namespace: default
```

---

## 🧪 Testing Security Implementation

### Test HTTPS
```bash
curl -v https://dhakacart.example.com
# Should show certificate details
```

### Test rate limiting
```bash
for i in {1..110}; do
  curl -i http://localhost:5000/api/test 2>/dev/null | head -1
done
# Should see 429 Too Many Requests after 100th request
```

### Test JWT
```bash
# Get token
TOKEN=$(curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password"}' \
  | jq -r '.token')

# Use token
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/api/protected
```

### Test input validation
```bash
# Should fail - invalid username
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"a","password":"password"}'

# Should fail - missing password
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin"}'
```

---

## 📋 Security Hardening Checklist

Before marking Phase 3 complete:

- [ ] HTTPS certificates generated and installed
- [ ] All endpoints respond over HTTPS
- [ ] Rate limiting active (test with script)
- [ ] JWT tokens required for protected endpoints
- [ ] Input validation on all user inputs
- [ ] No hardcoded secrets in code
- [ ] Secrets scanning enabled in GitHub
- [ ] Pod security standards applied
- [ ] RBAC roles created and assigned
- [ ] Security tests passing (see above)
- [ ] Documentation updated
- [ ] All changes committed to git

---

## 🎯 Completion Criteria

**Security Phase will be complete when:**
1. ✅ All endpoints serve HTTPS with valid certificates
2. ✅ Rate limiting prevents brute force attacks
3. ✅ JWT authentication protects sensitive endpoints
4. ✅ Input validation prevents injection attacks
5. ✅ No secrets in code or git history
6. ✅ All security tests passing
7. ✅ Documentation complete

**Estimated Time:** 5-7 hours total

---

## 📚 Reference Links

- Let's Encrypt Docs: https://letsencrypt.org/docs/
- cert-manager: https://cert-manager.io/docs/
- express-rate-limit: https://github.com/nfriedly/express-rate-limit
- JWT: https://jwt.io/
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- Kubernetes Security: https://kubernetes.io/docs/concepts/security/

---

**Start Date:** December 11, 2025
**Target Completion:** December 12, 2025
