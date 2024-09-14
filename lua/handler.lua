-- handler.lua
local cjson = require "cjson.safe"
local http = require "resty.http"
local resty_lock = require "resty.lock"
local rate_limiter = require "custom.rate_limiter"
local token_calculator = require "custom.token_calculator"
local cache = require "custom.cache"
local circuit_breaker = require "custom.circuit_breaker"
local utils = require "custom.utils"

local prometheus = require("resty.prometheus")
local metrics = metrics  -- Use the metrics initialized in nginx.conf

-- Start measuring latency
local start_time = ngx.now()

-- Read and parse request body
ngx.req.read_body()
local body_data = ngx.req.get_body_data()
local request_body, err = cjson.decode(body_data)
if not request_body then
    ngx.log(ngx.ERR, "Invalid JSON: ", err)
    metrics.errors:inc(1, {"invalid_json", "unknown"})
    return ngx.exit(400)
end

local model = request_body.model or "unknown"
metrics.requests:inc(1, {model})

-- Security enhancements: Validate API Key (if applicable)
local api_key = ngx.req.get_headers()["Authorization"]
if not utils.validate_api_key(api_key) then
    ngx.log(ngx.ERR, "Unauthorized access attempt")
    metrics.errors:inc(1, {"unauthorized", model})
    return ngx.exit(401)
end

-- Check circuit breaker state
if circuit_breaker.is_open(model) then
    ngx.log(ngx.ERR, "Circuit breaker is open for model: ", model)
    metrics.errors:inc(1, {"circuit_breaker_open", model})
    metrics.circuit_breaker:set(1, {model})  -- 1 indicates open state
    return ngx.exit(503)
end
metrics.circuit_breaker:set(0, {model})  -- 0 indicates closed state

-- Check cache
local cache_key = cache.generate_key(request_body)
local cached_response = cache.get(cache_key)
if cached_response then
    ngx.log(ngx.INFO, "Cache hit for key: ", cache_key)
    metrics.cache_hits:inc(1, {model})
    local latency = ngx.now() - start_time
    metrics.request_latency:observe(latency, {model})
    ngx.status = 200
    ngx.say(cached_response)
    return ngx.exit(200)
else
    metrics.cache_misses:inc(1, {model})
end

-- Acquire lock for rate limiting
local lock, err = resty_lock:new("locks")
local elapsed, err = lock:lock("rate_limit_lock_" .. model)
if not elapsed then
    ngx.log(ngx.ERR, "Failed to acquire lock: ", err)
    metrics.errors:inc(1, {"lock_error", model})
    return ngx.exit(500)
end

-- Rate limiting
local allowed, err = rate_limiter.is_allowed(model)
if not allowed then
    ngx.log(ngx.ERR, "Rate limit exceeded for model: ", model)
    metrics.errors:inc(1, {"rate_limit_exceeded", model})
    lock:unlock()
    return ngx.exit(429)
end
metrics.token_bucket:set(rate_limiter.get_token_bucket_level(model), {model})

lock:unlock()

-- Token calculation
local tokens_required, err = token_calculator.calculate(request_body)
if not tokens_required then
    ngx.log(ngx.ERR, "Token calculation failed: ", err)
    metrics.errors:inc(1, {"token_calc_error", model})
    return ngx.exit(500)
end

-- Deduct tokens
rate_limiter.deduct_tokens(model, tokens_required)

-- Call OpenAI API with circuit breaker
local res, err = circuit_breaker.call(model, function()
    -- Make API request to OpenAI
    local httpc = http.new()
    local res, err = httpc:request_uri("https://api.openai.com/v1/chat/completions", {
        method = "POST",
        body = cjson.encode(request_body),
        headers = {
            ["Authorization"] = "Bearer " .. os.getenv("OPENAI_API_KEY"),
            ["Content-Type"] = "application/json"
        },
        ssl_verify = true
    })
    return res, err
end)

if not res then
    ngx.log(ngx.ERR, "Failed to get response from OpenAI API: ", err)
    metrics.errors:inc(1, {"openai_api_error", model})
    return ngx.exit(500)
end

-- Cache the response
cache.set(cache_key, res.body)

-- Record request latency
local latency = ngx.now() - start_time
metrics.request_latency:observe(latency, {model})

-- Return response
ngx.status = res.status
ngx.say(res.body)
ngx.exit(res.status)
