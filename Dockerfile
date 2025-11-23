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

# 4. INTELLIGENT BUILD FIX
# We check where index.html is. If it's missing in root, we look for a 'client' folder.
RUN if [ -f "index.html" ]; then \
      echo "Found index.html in root. Building..."; \
      npx vite build; \
    elif [ -d "client" ]; then \
      echo "Found client directory. Building inside client..."; \
      cd client && pnpm install && npx vite build && mv dist ../dist; \
    else \
      echo "CRITICAL ERROR: Could not find source code structure."; \
      ls -R; \
      exit 1; \
    fi

# STAGE 2: The Wisp Python Backend
FROM python:3.11-slim

RUN useradd -m -u 1000 scramjet
WORKDIR /app

RUN pip install --no-cache-dir wisp-python

# Copy the compiled frontend
# This will FAIL intentionally if the build above didn't work, 
# preventing you from deploying a broken app.
COPY --from=builder /app/dist /app/client

USER scramjet
EXPOSE 8080

CMD ["python3", "-m", "wisp.server", "--host", "0.0.0.0", "--port", "8080", "--static", "/app/client", "--limits", "--connections", "50", "--log-level", "info"]
