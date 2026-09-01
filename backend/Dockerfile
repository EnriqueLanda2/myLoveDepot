# Debian en lugar de Alpine: numpy y Pillow traen ruedas precompiladas para
# glibc, así que la imagen se arma sin compilar nada.
FROM node:22-bookworm-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-bookworm-slim AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# La imagen oficial de Python ya trae el runtime sin depender de apt durante el
# build. Se copia únicamente el binario de Node y las dependencias productivas.
FROM python:3.12-slim-bookworm
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /usr/local/bin/node /usr/local/bin/node

COPY tools/model3d/requirements.txt ./tools/model3d/requirements.txt
RUN pip install --no-cache-dir -r tools/model3d/requirements.txt
ENV MODEL3D_PYTHON=/usr/local/bin/python

COPY package*.json ./
COPY --from=dependencies /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY schema.sql ./schema.sql
COPY tools ./tools

EXPOSE 3000
# El esquema se aplica antes de escuchar: la tabla de categorías y las columnas
# del modelo 3D tienen que existir cuando entre la primera petición.
CMD ["sh", "-c", "node dist/migrate.js && node dist/server.js"]
