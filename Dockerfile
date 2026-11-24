FROM mcr.microsoft.com/playwright:v1.45.0-jammy

WORKDIR /app

# Copy files and install
COPY backend/package*.json ./backend/
RUN cd backend && npm install

COPY backend/ ./backend/
RUN cd backend && npm run build

EXPOSE 10000

ENV PORT=10000
ENV HEADLESS=true
ENV NODE_ENV=production

CMD ["node", "backend/dist/Server.js"]
