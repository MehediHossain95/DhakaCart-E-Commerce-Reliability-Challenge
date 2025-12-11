const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';

// CORS Configuration with specific allowed origins
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',')
  : ['http://localhost:3000', 'http://localhost:5000', 'https://dhakacart.example.com'];

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
  maxAge: 86400 // 24 hours
};

app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));

// Rate Limiting Configuration
// Global rate limiter: 100 requests per 15 minutes per IP
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true, // return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // disable the `X-RateLimit-*` headers
  skip: (req) => req.path === '/health' || req.path === '/ready', // skip health checks
});

// Strict rate limiter for login: 5 attempts per 15 minutes per IP
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: 'Too many login attempts, please try again later.',
  skipSuccessfulRequests: true, // only count failed attempts
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(globalLimiter);

// Logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    const rateLimit = req.rateLimit;
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} - ${res.statusCode} (${duration}ms)${rateLimit ? ` [RateLimit: ${rateLimit.current}/${rateLimit.limit}]` : ''}`);
  });
  next();
});

// JWT Verification Middleware
const verifyToken = (req, res, next) => {
  const token = req.headers['authorization']?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      console.error('Token verification failed:', err.message);
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    req.userId = decoded.userId;
    req.username = decoded.username;
    next();
  });
};

// Input validation rules
const validateLogin = [
  body('username')
    .trim()
    .notEmpty().withMessage('Username is required')
    .isLength({ min: 3, max: 20 }).withMessage('Username must be between 3 and 20 characters')
    .matches(/^[a-zA-Z0-9_]+$/).withMessage('Username can only contain letters, numbers, and underscores')
    .escape(),
  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
];

// Health endpoint for Kubernetes liveness probe
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Ready endpoint for Kubernetes readiness probe
app.get('/ready', (req, res) => {
  res.status(200).json({ 
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// Main API endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: "DhakaCart API is Online!", 
    system_status: "Healthy", 
    timestamp: new Date().toISOString(),
    version: "1.0.0",
    environment: process.env.NODE_ENV || "development"
  });
});

// Authentication endpoint
app.post('/api/auth/login', loginLimiter, validateLogin, (req, res) => {
  // Check validation results
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { username, password } = req.body;

  // TODO: Replace with database lookup and bcrypt password verification
  // For now, using simple demo credentials
  if (username === 'admin' && password === 'Secure123!') {
    const token = jwt.sign(
      { userId: 1, username },
      JWT_SECRET,
      { expiresIn: '24h' }
    );
    return res.json({ 
      message: 'Login successful',
      token,
      expiresIn: '24h'
    });
  }

  res.status(401).json({ error: 'Invalid username or password' });
});

// Get products endpoint (public)
app.get('/api/products', (req, res) => {
  const products = [
    {
      id: 1,
      name: "Samsung Galaxy S23",
      price: 89999,
      category: "Electronics",
      stock: 50
    },
    {
      id: 2,
      name: "iPhone 15 Pro",
      price: 149999,
      category: "Electronics",
      stock: 30
    },
    {
      id: 3,
      name: "Sony WH-1000XM5",
      price: 29999,
      category: "Accessories",
      stock: 100
    }
  ];
  
  res.json({ products });
});

// Protected endpoint example
app.get('/api/protected', verifyToken, (req, res) => {
  res.json({ 
    message: 'This is a protected endpoint',
    userId: req.userId,
    username: req.username,
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(`[ERROR] ${err.message}`, err.stack);
  
  // Handle CORS errors
  if (err.message === 'Not allowed by CORS') {
    return res.status(403).json({
      error: 'CORS Error',
      message: 'Origin not allowed'
    });
  }
  
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'An error occurred'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found', path: req.path });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

const server = app.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] DhakaCart Backend Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Allowed Origins: ${allowedOrigins.join(', ')}`);
});
