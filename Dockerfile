FROM alpine:latest

# Install Lua 5.1 and dependencies for Luvit
RUN apk add --no-cache \
    lua5.1 \
    curl \
    bash \
    git \
    gcc \
    musl-dev \
    make

# Install Luvit
RUN curl -fsSL https://github.com/luvit/lit/raw/master/get-lit.sh | sh
RUN mv luvit lit luvi /usr/local/bin/

# Working directory
WORKDIR /app

# Copy Source Code
COPY . .

# Environment
ENV MASTER_KEY=LUASEC.CC
ENV PORT=11081

# Expose
EXPOSE 11081

# Start Luvit Server
CMD ["luvit", "api/server.lua"]
