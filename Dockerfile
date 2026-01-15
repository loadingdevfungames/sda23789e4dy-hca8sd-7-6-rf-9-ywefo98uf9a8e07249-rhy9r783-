FROM alpine:latest

# Install Lua 5.1, Luarocks, and build dependencies
RUN apk add --no-cache \
    lua5.1 \
    lua5.1-dev \
    luarocks \
    gcc \
    musl-dev \
    make

# Install Lua packages
RUN luarocks install pegasus
RUN luarocks install dkjson

# Working directory
WORKDIR /app

# Copy Source Code
COPY . .

# Environment
ENV MASTER_KEY=LUASEC.CC
ENV PORT=11081

# Expose
EXPOSE 11081

# Start Lua Server
CMD ["lua", "api/server.lua"]
