state.var {
  var = state.value()
}

timer = "Amhs1ivmaJco4vyVYgZFjFYnit47RukSFeeBd5iNP5iPFB2YbBiN"
call_price = "100000000000000000"

function on_timer(arg)

  assert(system.getSender() == timer, "only the timer contract can call this function")

  var:set(arg)

end

function use_timer(interval, arg)

  var:set("empty")

  contract.call.value(call_price)(timer, "start", interval, "on_timer", arg)

end

function transfer()
  -- do nothing, only receive tokens
end

abi.payable(transfer)
abi.register(use_timer, on_timer)


--[[

Available Lua modules:
  string  math  table  bit

Available Aergo modules:
  system  contract  db  crypto  bignum  json

]]
