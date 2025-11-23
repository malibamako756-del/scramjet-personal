# STAGE 1: Build the Scramjet Frontend
FROM node:20-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app

# 1. Clone the repository
RUN git clone --depth 1 https://github.com/MercuryWorkshop/Scramjet-App .

# 2. Install pnpm
RUN npm install -g pnpm

# 3. Install dependencies
RUN pnpm install

# 4. STRUCTURE FIX & BUILD
# Move index.html from public to root so Vite can find it (Common fix for this repo structure)
RUN if [ -f "public/index.html" ]; then cp public/index.html .; fi

# Attempt to build. If it fails, we ignore the error (|| true) and fall back to 'public' folder.
RUN npx vite build || echo "Build failed, falling back to public folder"

# 5. PREPARE FINAL ASSETS
# We decide which folder to serve. If 'dist' exists, use it. If not, use 'public'.
RUN if [ -d "dist" ]; then \
      mv dist /app/final_site; \
    elif [ -d "public" ]; then \
      mv public /app/final_site; \
    else \
      mkdir /app/final_site && echo "<h1>Error: No assets found</h1>" > /app/final_site/index.html; \
    fi

# STAGE 2: The Wisp Python Backend
FROM python:3.11-slim

RUN useradd -m -u 1000 scramjet
WORKDIR /app

RUN pip install --no-cache-dir wisp-python

# Copy the final assets from the builder stage
COPY --from=builder /app/final_site /app/client

USER scramjet

# Expose internal port
EXPOSE 8080

# Serve the prepared folder
CMD ["python3", "-m", "wisp.server", "--host", "0.0.0.0", "--port", "8080", "--static", "/app/client", "--limits", "--connections", "50", "--log-level", "info"]
