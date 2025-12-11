const express = require('express');
const cors = require('cors');
const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*'
}));
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} - ${res.statusCode} (${duration}ms)`);
  });
  next();
});

// Health endpoint for Kubernetes liveness probe
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// Ready endpoint for Kubernetes readiness probe
app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready' });
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

// Example products endpoint
app.get('/api/products', (req, res) => {
  res.json({
    products: [
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
    ]
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(`[ERROR] ${err.message}`, err.stack);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'An error occurred'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
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
});
