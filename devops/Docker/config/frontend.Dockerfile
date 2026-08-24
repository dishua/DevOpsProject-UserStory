# Build stage
#======================================
FROM node:20.11.0-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

ARG BACKEND_URL=/api

ENV REACT_APP_BACKEND_URL=$BACKEND_URL

RUN npm run build


# Run stage
#======================================
FROM nginx:alpine

COPY --from=builder /app/build/ /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]