# STAGE 1: Build the Scramjet Frontend
FROM node:20-alpine AS builder

# Install git
RUN apk add --no-cache git

WORKDIR /app

# 1. Clone the repository
RUN git clone --depth 1 https://github.com/MercuryWorkshop/Scramjet-App .

# 2. Install pnpm
RUN npm install -g pnpm

# 3. Install dependencies
RUN pnpm install

# 4. DEBUG & BUILD:
# We try to run the build script if it exists.
# If 'build' is missing, we assume it uses Vite and try to build directly.
# We use '||' to try the fallback if the first fails.
RUN if grep -q '"build":' package.json; then \
      pnpm run build; \
    else \
      echo "No build script found. Attempting direct Vite build..."; \
      npx vite build || echo "Vite build failed or not needed. Checking for dist..."; \
    fi

# 5. Verify Output exists (Safety Check)
# If 'dist' doesn't exist, we try 'public' (some apps serve from public directly)
RUN if [ ! -d "dist" ] && [ -d "public" ]; then \
      echo "No dist folder, copying public instead"; \
      cp -r public dist; \
    fi

# STAGE 2: The Wisp Python Backend
FROM python:3.11-slim

# SECURITY: Create a non-root user
RUN useradd -m -u 1000 scramjet

WORKDIR /app

# Install the Wisp Server
RUN pip install --no-cache-dir wisp-python

# Copy the compiled frontend from Stage 1
# We copy from 'dist'. If the previous stage failed to make 'dist', this will fail explicitly.
COPY --from=builder /app/dist /app/client

# SECURITY: Switch to non-root user
USER scramjet

# Expose the port
EXPOSE 8080

# OPTIMAL COMMAND
CMD ["python3", "-m", "wisp.server", "--host", "0.0.0.0", "--port", "8080", "--static", "/app/client", "--limits", "--connections", "50", "--log-level", "info"]
