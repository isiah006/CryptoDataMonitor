FROM mcr.microsoft.com/playwright:v1.45.0-jammy

WORKDIR /app

# Copy files and install
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

EXPOSE 10000

ENV PORT=10000
ENV HEADLESS=true
ENV NODE_ENV=production

CMD ["node", "dist/Server.js"]
