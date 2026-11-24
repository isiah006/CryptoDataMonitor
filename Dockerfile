FROM mcr.microsoft.com/playwright:v1.45.0-jammy

WORKDIR /app

# Copy project files
COPY . .

# Install all dependencies (including TypeScript devDependencies) and build TypeScript
RUN cd backend && npm install --include=dev && npm run build

EXPOSE 10000

ENV PORT=10000
ENV HEADLESS=true
ENV NODE_ENV=production

CMD ["node", "backend/dist/Server.js"]
