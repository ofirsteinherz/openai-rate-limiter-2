-- cache.lua
local _M = {}
local ngx_shared = ngx.shared.cache_store
local cjson = require "cjson.safe"

function _M.generate_key(request_body)
    -- Generate a cache key based on request content
    local key = cjson.encode(request_body)
    return ngx.md5(key)
end

function _M.get(key)
    return ngx_shared:get(key)
end

function _M.set(key, value)
    -- Set cache with a TTL (e.g., 5 minutes)
    ngx_shared:set(key, value, 300)
end

return _M
