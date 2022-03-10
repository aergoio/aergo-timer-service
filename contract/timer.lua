state.var {
  last_timer_id = state.value(),
  timers = state.map()
}
            -- 0.123456789012345678
call_price_str = "10000000000000000"  -- 0.01 AERGO
call_price_aergo = "0.01 aergo"

function constructor()
  last_timer_id:set(0)
end

local function new_timer(caller, amount, interval, callback, ...)

  assert(caller ~= system.getOrigin(), "the timer is intended to be used by other contracts")

  local call_price = bignum.number(call_price_str)

  -- check the payment for this call
  assert(amount >= call_price, "the minimum call price is " .. call_price_aergo .. " (" .. call_price_str  .. ")")
  local amount_str = bignum.tostring(amount)

  -- check the time interval for the call
  local fire_time = 0
  if type(interval) == 'string' and interval:sub(1,3) == "on " then
    fire_time = tonumber(interval:sub(4))
    assert(fire_time > system.getTimestamp(), "the fire time must be in the future")
  else
    if type(interval) ~= 'number' then
      interval = tonumber(interval)
    end
    assert(interval > 0, "the interval must be positive")
    -- calculate the fire time
    fire_time = system.getTimestamp() + interval
  end

  local info = {
    time = fire_time,
    address = caller,   -- should it allow a contract to register callback on another?
    callback = callback,
    args = {...},
    amount = amount_str
  }

  -- get a new timer id
  local timer_id = last_timer_id:get() + 1
  last_timer_id:set(timer_id)

  -- store the timer info
  timers[timer_id] = info

  -- notify the listening off-chain nodes
  -- discard the last 15 chars from the payment
  local payment = tonumber(amount_str:sub(1, #amount_str - 15))
  contract.event("new_timer", timer_id, fire_time, payment)

  return timer_id
end

-- native aergo tokens
function start(interval, callback, ...)
  local caller = system.getSender()
  local amount = bignum.number(system.getAmount())

  return new_timer(caller, amount, interval, callback, ...)
end

-- wrapped aergo (waergo) ARC1 tokens
function tokensReceived(operator, from, amount, ...)
  local token = system.getSender()

  local before = bignum.number(contract.balance())
  contract.call(token, "unwrap", amount)
  local amount2 = bignum.number(contract.balance()) - before
  assert(amount2 == amount, "invalid amount")

  return new_timer(from, amount, ...)
end

function stop(timer_id)

  if type(timer_id) ~= 'number' then
    timer_id = tonumber(timer_id)
  end

  local info = timers[timer_id]
  assert(info ~= nil, "timer not found")

  -- only the called component can stop a timer
  assert(system.getSender() == info["address"], "not authorized")

  -- delete the timer
  timers:delete(timer_id)

  -- return the payment for the call
  contract.send(info["address"], info["amount"])

  -- notify the listening off-chain nodes
  contract.event("processed", timer_id)

end

-- anyone can call this function
function fire_timer(timer_id)

  if type(timer_id) ~= 'number' then
    timer_id = tonumber(timer_id)
  end

  -- check if the timer exists
  local info = timers[timer_id]
  assert(info ~= nil, "timer not found")

  -- check if it can be fired now, using the current time
  assert(system.getTimestamp() >= info["time"], "this timer can only be fired after " .. info["time"])

  -- update the state BEFORE any external call to avoid reentrancy attack
  -- remove the timer
  timers:delete(timer_id)

  -- fire the callback
  -- contract.call(info["address"], info["callback"], unpack(info["args"]))
  local success, result = pcall(contract.call, info["address"], info["callback"], unpack(info["args"]))

  -- issue an event
  contract.event("processed", timer_id, success, result)

  -- pay the node
  contract.send(system.getOrigin(), info["amount"])

end

function default()
  -- used to receive aergo tokens (unwrap waergo)
end

abi.payable(start, default)
abi.register(start, stop, fire_timer, tokensReceived)
