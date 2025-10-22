# --- Estágio 1: Build ---
# Usamos a imagem oficial do Node 20 com base Debian (para ter o apt-get)
FROM node:20-bullseye-slim AS builder
WORKDIR /app

# Instala dependências do sistema operacional necessárias (ex: para gerar vídeos/gifs)
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/*

# Copia os arquivos de pacote e instala as dependências de produção
COPY package*.json ./
RUN npm install --omit=dev --force

# Copia o restante do código-fonte
COPY . .

# Gera o cliente Prisma (isso NÃO precisa de conexão com o banco)
RUN npx prisma generate

# Compila o TypeScript para JavaScript
# Usamos o script específico de compilação, ignorando o "db:push"
RUN npm run build:tsc


# --- Estágio 2: Produção ---
# Começa de uma imagem limpa e enxuta
FROM node:20-bullseye-slim AS production
WORKDIR /app

# Cria um usuário não-root por segurança
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 codechat

# Instala as dependências de produção do sistema operacional
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/*

# Copia apenas os artefatos necessários do estágio 'builder'
# e define o usuário 'codechat' como proprietário
COPY --from=builder --chown=codechat:nodejs /app/dist ./dist
COPY --from=builder --chown=codechat:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=codechat:nodejs /app/package*.json ./
COPY --from=builder --chown=codechat:nodejs /app/prisma ./prisma
COPY --from=builder --chown=codechat:nodejs /app/public ./public
COPY --from=builder --chown=codechat:nodejs /app/views ./views

# Define o usuário não-root para rodar a aplicação
USER codechat

# Expõe a porta que a aplicação usa
EXPOSE 8080

# Comando padrão para iniciar o servidor.
# A migração do banco será feita pelo Coolify no "Start Command".
CMD ["node", "./dist/src/main.js"]
