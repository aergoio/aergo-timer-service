state.var {
  var = state.value()
}

timer = "Amg4JPhdKoPbeqjBvUTX2i6Z9z8t5uV2NiCEnYdWQLyusf9ocepf"
call_price = "10000000000000000" -- 0.01 aergo = minimum

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
