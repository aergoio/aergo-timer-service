# Aergo Timer Service ⏰

Create timers to call functions on your smart contracts

Schedule calls based on time interval or on specific date-times

For a small fee (minimum 0.01 AERGO) per call

The Aergo Timer Service is a **trustless** service that uses off-chain nodes to interface with the Aergo blockchain


## How To Use It

### Step 1

Add these 2 lines at the top of your contract:

```lua
timer = "Amhs1ivmaJco4vyVYgZFjFYnit47RukSFeeBd5iNP5iPFB2YbBiN"
call_price = "10000000000000000" -- 0.01 aergo = minimum
```

They define the address of the Timer contract and the price for a single call


### Step 2

Create the function that should be called, with a single argument, and add this line of code at the beginning to limit who can call it:

```lua
assert(system.getSender() == timer, "only the timer contract can call this function")
```


### Step 3

Create a timer using this line:

```lua
contract.call.value(call_price)(timer, "start", interval, callback, argument)
```

The `interval` can be:

* The amount of time in seconds, as an integer
* The specific time in Unix timestamp format without the milliseconds, as a string that starts with "on "

The `callback` is the name of the function that should be called on the contract (from step 2).

It is possible to pass an `argument` to the callback function. If you need to pass many, just serialize them as a string and deserialize on the callback.

#### Examples:

1. This one creates a timer to be executed within 30 seconds:

```lua
contract.call.value(call_price)(timer, "start", 30, "on_timer", arg)
```

2. This one creates a timer to be executed within 2 days (172800 seconds):

```lua
contract.call.value(call_price)(timer, "start", 172800, "on_deadline", arg)
```

3. This one creates a timer to be executed on 2022-10-15 09:30:00 UTC (Unix timestamp 1665826200):

```lua
contract.call.value(call_price)(timer, "start", "on 1665826200", "contract_end", arg)
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
node off-chain-node.js
```

It is recommended to run it as a service, so it is restarted on failure.
One example using `pm2`:

```
pm2 start off-chain-node.js
```
