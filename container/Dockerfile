FROM node:12 AS builder

WORKDIR /src
COPY package.json .
COPY package-lock.json .

RUN npm ci

FROM node:12

EXPOSE 3000
CMD ["node", "app.js"]

WORKDIR /app
COPY --from=builder /src/node_modules/ /app/node_modules/
COPY src/ .
