-- circuit_breaker.lua
local _M = {}
local ngx_shared = ngx.shared.circuit_breaker_store

function _M.is_open(model)
    local state_key = "cb_state_" .. model
    local failure_count_key = "cb_failure_count_" .. model
    local open_until_key = "cb_open_until_" .. model

    local state = ngx_shared:get(state_key) or "closed"
    if state == "open" then
        local open_until = ngx_shared:get(open_until_key) or 0
        if ngx.now() >= open_until then
            -- Move to half-open state
            ngx_shared:set(state_key, "half_open")
            return false
        end
        return true
    end
    return false
end

function _M.call(model, func)
    local state_key = "cb_state_" .. model
    local failure_count_key = "cb_failure_count_" .. model
    local open_until_key = "cb_open_until_" .. model

    local res, err = func()
    if res and res.status == 200 then
        -- Success, reset failure count
        ngx_shared:set(failure_count_key, 0)
        ngx_shared:set(state_key, "closed")
        return res, nil
    else
        -- Failure, increment failure count
        local failures = ngx_shared:incr(failure_count_key, 1, 0)
        if failures >= 5 then
            -- Open circuit
            ngx_shared:set(state_key, "open")
            ngx_shared:set(open_until_key, ngx.now() + 30)  -- Open for 30 seconds
        end
        return nil, err or "API call failed"
    end
end

return _M
