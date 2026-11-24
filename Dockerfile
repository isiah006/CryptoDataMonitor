FROM mcr.microsoft.com/playwright:v1.45.0-jammy

WORKDIR /app/backend

# Force development environment for npm install to ensure typescript & @types are installed
ENV NODE_ENV=development

# Copy package files
COPY backend/package*.json ./
RUN npm install

# Copy source code and configuration
COPY backend/ ./

# Compile TypeScript to dist
RUN npx tsc

# Runtime Environment
ENV NODE_ENV=production
ENV PORT=10000
ENV HEADLESS=true

EXPOSE 10000

CMD ["node", "dist/Server.js"]
