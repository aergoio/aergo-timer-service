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

function start(interval, callback, args)

  local call_price = bignum.number(call_price_str)

  -- check the payment for this call
  local amount_str = system.getAmount()
  local amount = bignum.number(amount_str)
  assert(bignum.compare(amount, call_price) >= 0, "the minimum call price is " .. call_price_aergo .. " (" .. call_price_str  .. ")")

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
    address = system.getSender(),   -- should it allow a contract to register callback on another?
    callback = callback,
    args = args,
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

  -- fire the callback
  -- contract.call(info["address"], info["callback"], info["args"])
  contract.pcall(contract.call, info["address"], info["callback"], info["args"])

  -- remove the timer
  timers:delete(timer_id)

  -- issue an event
  contract.event("processed", timer_id)

  -- pay the node
  contract.send(system.getOrigin(), info["amount"])

end

abi.payable(start)
abi.register(start, stop, fire_timer)

--[[

Available Lua modules:
  string  math  table  bit

Available Aergo modules:
  system  contract  db  crypto  bignum  json

]]
