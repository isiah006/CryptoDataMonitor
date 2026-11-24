FROM mcr.microsoft.com/playwright:v1.45.0-jammy

WORKDIR /app

# Copy all project files
COPY . .

# Install dependencies and compile TypeScript directly via tsconfig
RUN cd backend && npm install && npx tsc

EXPOSE 10000

ENV PORT=10000
ENV HEADLESS=true
ENV NODE_ENV=production

CMD ["node", "backend/dist/Server.js"]
