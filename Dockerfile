FROM mcr.microsoft.com/playwright:v1.45.0-jammy

WORKDIR /app

# Copy all project files
COPY . .

# Install dependencies and build TypeScript (handles both root and backend context)
RUN if [ -d "backend" ]; then cd backend; fi && npm install && npm run build

EXPOSE 10000

ENV PORT=10000
ENV HEADLESS=true
ENV NODE_ENV=production

CMD ["sh", "-c", "if [ -d \"backend\" ]; then cd backend; fi && node dist/Server.js"]
