# /!\ NOTICE /!\

# Many of the developers DO NOT USE the Dockerfile or image.
# While we do test new changes to Docker configuration, it's
# possible that future changes to the repo might break it.
# When changing this file, please try to make it as resiliant
# to such changes as possible; developers shouldn't need to
# worry about Docker unless the build/run process changes.

# Build stage ================================================================
FROM node:23.9-alpine AS build

# Install build dependencies
RUN apk add --no-cache git python3 make g++ \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Set up working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Copy the source files
COPY . .

# Install mocha
RUN npm install -g mocha

# Install node modules
RUN npm cache clean --force && \
    for i in 1 2 3; do \
    npm ci && break || \
    if [ $i -lt 3 ]; then \
    sleep 15; \
    else \
    exit 1; \
    fi; \
    done

ARG NODE_ENV=production
ARG VITE_PUTER_API_URL=http://puter.localhost:4100
ARG VITE_PARTICLE_PROJECT_ID=your_particle_project_id
ARG VITE_PARTICLE_CLIENT_KEY=particle_client
ARG VITE_PARTICLE_APP_ID=your_particle_app_id
ARG VITE_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id

ENV VITE_PUTER_API_URL=${VITE_PUTER_API_URL}
ENV VITE_PARTICLE_PROJECT_ID=${VITE_PARTICLE_PROJECT_ID}
ENV VITE_PARTICLE_CLIENT_KEY=${VITE_PARTICLE_CLIENT_KEY}
ENV VITE_PARTICLE_APP_ID=${VITE_PARTICLE_APP_ID}
ENV VITE_WALLETCONNECT_PROJECT_ID=${VITE_WALLETCONNECT_PROJECT_ID}

# Run the build command if necessary
RUN npm run build

# Production stage ===========================================================
FROM node:23.9-alpine

# Set labels
LABEL repo="https://github.com/WAUIO/pc2.net"
LABEL license="AGPL-3.0,https://github.com/WAUIO/pc2.net/blob/master/LICENSE.txt"
LABEL version="1.2.47-elastos-1"

# Install git (required by Puter to check version)
RUN apk add --no-cache git

# Set up working directory
RUN mkdir -p /opt/puter/app
WORKDIR /opt/puter/app

# Copy built artifacts and necessary files from the build stage
COPY --from=build /app/src/gui/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY . .
COPY --from=build /app/src/particle-auth ./src/particle-auth

# Set permissions
RUN chown -R node:node /opt/puter/app
USER node

EXPOSE 4100

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://puter.localhost:4100/test || exit 1

ENV NO_VAR_RUNTUME=1

# Attempt to fix `lru-cache@11.0.2` missing after build stage
# by doing a redundant `npm install` at this stage
RUN npm install

# Fix for aarch64
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then \
    npm install --os=linux --libc=musl --cpu=arm64 sharp; \
    fi

CMD ["npm", "start"]
