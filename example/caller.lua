state.var {
  var = state.value()
}

timer = "AmhWD5WtbScVHWS2N4Rhy6CHCm4AVGjzA1HyDywUfnrURSHvHgAh"
call_price = "10000000000000000" -- 0.01 aergo = minimum

function get_value()
  return var:get()
end

function on_timer(arg)

  assert(system.getSender() == timer, "only the timer contract can call this function")

  var:set(arg)

end

function use_timer(interval, arg)

  var:set("empty")

  contract.call.value(call_price)(timer, "start", interval, "on_timer", arg)

end

function use_timer2(waergo, interval, arg)

  var:set("empty")

  contract.call(waergo, "transfer", timer, call_price, interval, "on_timer", arg)

end

function transfer()
  -- do nothing, only receive tokens
end

-- wrapped aergo (waergo) ARC1 tokens
function tokensReceived(operator, from, amount, ...)

end

abi.payable(transfer)
abi.register(use_timer, use_timer2, on_timer, tokensReceived)
abi.register_view(get_value)
