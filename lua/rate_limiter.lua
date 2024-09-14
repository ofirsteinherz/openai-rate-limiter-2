-- rate_limiter.lua
local _M = {}
local ngx_shared = ngx.shared.rate_limiter_store

function _M.is_allowed(model)
    -- Load model limits
    local model_limits = {
        ["gpt-4o"] = { token_limit_per_minute = 2000, request_limit_per_minute = 5000 },
        ["gpt-4o-mini"] = { token_limit_per_minute = 2000000, request_limit_per_minute = 5000 },
        ["gpt-3.5-turbo"] = { token_limit_per_minute = 2000000, request_limit_per_minute = 5000 },
    }

    local limits = model_limits[model]
    if not limits then
        return false, "Model not supported"
    end

    local tokens_key = "tokens_" .. model
    local requests_key = "requests_" .. model
    local last_refill_key = "last_refill_" .. model

    local token_bucket = ngx_shared:get(tokens_key) or limits.token_limit_per_minute
    local request_count = ngx_shared:get(requests_key) or 0

    -- Refill tokens
    local now = ngx.now()
    local last_refill = ngx_shared:get(last_refill_key) or now
    local elapsed = now - last_refill
    local refill_rate = limits.token_limit_per_minute / 60  -- tokens per second
    local new_tokens = math.min(token_bucket + (elapsed * refill_rate), limits.token_limit_per_minute)

    ngx_shared:set(tokens_key, new_tokens)
    ngx_shared:set(last_refill_key, now)

    -- Check limits
    if request_count >= limits.request_limit_per_minute then
        return false, "Request limit exceeded"
    end

    return true
end

function _M.deduct_tokens(model, tokens)
    local tokens_key = "tokens_" .. model
    local requests_key = "requests_" .. model

    ngx_shared:incr(tokens_key, -tokens)
    ngx_shared:incr(requests_key, 1)
end

function _M.get_token_bucket_level(model)
    local tokens_key = "tokens_" .. model
    return ngx_shared:get(tokens_key) or 0
end

return _M
