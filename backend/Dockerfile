# backend/Dockerfile
FROM node:18-alpine

# 1. Set working directory
WORKDIR /app

# 2. Copy package files first (optimizes cache)
COPY package*.json ./

# 3. Install dependencies
RUN npm install --production

# 4. Copy application source code
COPY . .

# 5. SECURITY: Create a non-root user and switch to it
# (Alpine node images come with a 'node' user)
USER node

# 6. Expose the port the app runs on (usually 3000 or 5000)
EXPOSE 5000

# 7. Start the application
CMD ["node", "server.js"]
