-- token_calculator.lua
local _M = {}
local http = require "resty.http"
local cjson = require "cjson.safe"

function _M.calculate(request_body)
    local httpc = http.new()
    httpc:set_timeout(5000)  -- Set timeout as needed

    local res, err = httpc:request_uri("http://python-service:8001/calculate_tokens/", {
        method = "POST",
        body = cjson.encode(request_body),
        headers = {
            ["Content-Type"] = "application/json"
        }
    })

    if not res then
        return nil, "Failed to connect to token calculation service: " .. (err or "unknown error")
    end

    if res.status ~= 200 then
        return nil, "Token calculation service returned status: " .. res.status
    end

    local data, err = cjson.decode(res.body)
    if not data then
        return nil, "Failed to parse token calculation response: " .. (err or "unknown error")
    end

    if data.error then
        return nil, "Token calculation error: " .. data.error
    end

    local tokens_required = data.tokens
    if not tokens_required then
        return nil, "Token calculation service did not return tokens"
    end

    return tokens_required
end

return _M
