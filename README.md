# Aergo Timer Service ⏰

Create timers to call functions on your smart contracts

Schedule calls based on time interval or on specific date-times

For a small fee (minimum 0.01 AERGO) per call

The Aergo Timer Service is a **trustless** service that uses off-chain nodes to interface with the Aergo blockchain


## How To Use It

### Step 1

Add these 2 lines at the top of your contract:

For `testnet`:

```lua
timer = "Amg4JPhdKoPbeqjBvUTX2i6Z9z8t5uV2NiCEnYdWQLyusf9ocepf"
call_price = "10000000000000000" -- 0.01 aergo = minimum
```

For `mainnet`:

```lua
timer = "AmgVFEHns9wAXuJAtN8hHdFGzkzknRiyH3cYVLkEUT8fewoerzYv"
call_price = "10000000000000000" -- 0.01 aergo = minimum
```

They define the address of the Timer contract and the price for a single call


### Step 2

Create the function that should be called (it can have arguments) and add this line of code at the beginning to limit who can call it:

```lua
assert(system.getSender() == timer, "only the timer contract can call this function")
```


### Step 3

Create a timer using this line:

```lua
contract.call.value(call_price)(timer, "start", interval, callback, arguments...)
```

The `interval` can be:

* The amount of time in seconds, as an integer
* The specific time in Unix timestamp format without the milliseconds, as a string that starts with "on "

The `callback` is the name of the function that should be called on the contract (from step 2).

It is possible to pass `arguments` to the callback function.

#### Examples:

1. This one creates a timer to be executed within 30 seconds:

```lua
contract.call.value(call_price)(timer, "start", 30, "on_timer", arg1, arg2)
```

2. This one creates a timer to be executed within 2 days (172800 seconds):

```lua
contract.call.value(call_price)(timer, "start", 172800, "on_deadline", arg)
```

3. This one creates a timer to be executed on 2022-10-15 09:30:00 UTC (Unix timestamp 1665826200):

```lua
contract.call.value(call_price)(timer, "start", "on 1665826200", "contract_end")
```

There is also an [example contract](example/caller.lua)


## Call Fees

Although 0.01 aergo is sufficient for most calls, if your contract uses too much gas it will need to pay a higher amount for each call. You can call your contract function directly and check how much was the fee, then add 30% or more to the amount and use this value as the `call_price` on your contract.

The last 15 characters from the price must be zero.

> :warning: The call will **NOT** happen if the amount paid is lower than what is required to execute the function call!


## Node Runners

The Timer service uses off-chain nodes to process the timers.

A node is rewarded for each call as an economic incentive to keep running and pay the costs.

Although a single node is sufficient for the service, it is good to have more to cover down-time and to keep the service active.

To run a node, use a dedicated device with synchronized time. It is recommended to use a no-break to reduce down-time.

### Installation

Clone this repo, install `node.js` and the dependencies:

```
git clone https://github.com/aergoio/aergo-timer-service
cd aergo-timer-service/node_runner
npm install better-sqlite3 @herajs/client @herajs/crypto
```

### Running the node

To start it manually:

```
node off-chain-node.js testnet
```

It is recommended to run it as a service, so it is restarted on failure.
One example using `pm2`:

```
pm2 start off-chain-node.js -- testnet
```

For mainnet:

```
pm2 start off-chain-node.js -- mainnet
```

If you plan to run nodes for both networks, create a copy of the folder, rename the js file (they must be different on pm2) and run them separately.
