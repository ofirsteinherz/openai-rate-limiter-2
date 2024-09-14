FROM openresty/openresty:buster

# Install dependencies
RUN apt-get update && apt-get install -y \
    luarocks \
    git \
    build-essential \
    libssl-dev \
    liblua5.1-0-dev \
    ca-certificates

# Configure git to use HTTPS instead of git protocol
RUN git config --global url."https://".insteadOf git://

# Install Lua modules via luarocks
RUN luarocks install lua-resty-prometheus
RUN luarocks install lua-resty-http
RUN luarocks install lua-resty-lock

# Copy configuration files
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY lua/ /usr/local/openresty/lualib/custom/

EXPOSE 80
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
