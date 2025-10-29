# Étape 1 : builder
FROM node:20-slim AS builder

WORKDIR /app

# Installer OpenSSL pour Prisma
RUN apt-get update -y && apt-get install -y openssl

# Copier package.json et installer les dépendances
COPY package*.json ./
RUN npm ci

# Copier le reste du projet
COPY . .

# Générer Prisma Client
RUN npx prisma generate

# Construire Next.js
RUN npm run build

# Étape 2 : runner léger
FROM node:20-slim AS runner
WORKDIR /app

# Installer OpenSSL pour Prisma
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Copier les fichiers de package et installer seulement les dépendances de production
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production

# Copier le build standalone
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
COPY --from=builder /app/prisma ./prisma

# Copier les fichiers générés de Prisma
COPY --from=builder /app/src/generated ./src/generated

# Lancer le serveur
ENV DATABASE_URL="file:./dev.db"
ENV NODE_ENV="production"
ENV PORT="3000"
ENV HOSTNAME="0.0.0.0"
EXPOSE 3000

CMD ["node", "server.js"]
