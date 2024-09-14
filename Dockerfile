FROM openresty/openresty:alpine

RUN opm get kong/lua-resty-prometheus
RUN opm get ledgetech/lua-resty-http
RUN opm get openresty/lua-resty-lock

# Install LuaRocks and additional Lua libraries
RUN apk add --no-cache lua5.1-dev luarocks openssl-dev
RUN luarocks install lua-resty-openidc
RUN luarocks install lua-resty-jwt

COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY lua/ /usr/local/openresty/lualib/custom/

EXPOSE 80
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
