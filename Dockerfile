FROM mcr.microsoft.com/playwright:v1.45.0-jammy

WORKDIR /app

# Copy all project files
COPY . .

# Install dependencies and build TypeScript
RUN cd backend && npm install && npm run build

EXPOSE 10000

ENV PORT=10000
ENV HEADLESS=true
ENV NODE_ENV=production

CMD ["sh", "-c", "cd backend && node dist/Server.js"]
