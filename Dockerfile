FROM openresty/openresty:buster

# Install dependencies and LuaRocks
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    libssl-dev \
    liblua5.1-0-dev \
    ca-certificates \
    lua5.1 \
    luarocks

# Configure Git to use HTTPS instead of git://
RUN git config --global url."https://".insteadOf git://

# Install Lua modules via LuaRocks
RUN luarocks install lua-resty-prometheus
RUN luarocks install lua-resty-http
RUN luarocks install lua-resty-lock

# Copy configuration files
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY lua/ /usr/local/openresty/lualib/custom/

# Expose port 80
EXPOSE 80

# Start OpenResty and specify the configuration file
CMD ["openresty", "-g", "daemon off;", "-c", "/usr/local/openresty/nginx/conf/nginx.conf"]
