FROM mcr.microsoft.com/playwright:v1.45.0-jammy

WORKDIR /app

# Copy backend package files and install dependencies
COPY backend/package*.json ./
RUN npm install

# Copy backend source files and build TypeScript
COPY backend/ ./
RUN npm run build

EXPOSE 10000

ENV PORT=10000
ENV HEADLESS=true
ENV NODE_ENV=production

CMD ["node", "dist/Server.js"]
