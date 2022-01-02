const client = require('@herajs/client');
const crypto = require('@herajs/crypto');
const sqlite3 = require('better-sqlite3');
const fs = require('fs');

const aergo = new client.AergoClient({}, new client.GrpcProvider({url: 'testnet-api.aergo.io:7845'}));

// This is the address of the Aergo Timer contract
const contract_address = "Amhs1ivmaJco4vyVYgZFjFYnit47RukSFeeBd5iNP5iPFB2YbBiN"
const MIN_BLOCK = 83902017

var chainIdHash
var identity
var account

var timer
var timeout_id = 0

// store the timers on a local database, sorted by fire time
const db = new sqlite3('timers.db', { verbose: console.log })

// read or generate an account for this node
try {
  const privateKey = fs.readFileSync(__dirname + '/account.json')
  console.log('reading account from file...')
  identity = crypto.identityFromPrivateKey(privateKey)
} catch (err) {
  if (err.code == 'ENOENT') {
    console.log('generating new account...')
    identity = crypto.createIdentity()
    fs.writeFileSync(__dirname + '/account.json', identity.privateKey)
  } else {
    console.error(err)
    var process = require('process')
    process.exit(1)
  }
}

console.log('account address:', identity.address);

// call the Aergo Timer smart contract
async function call_timer(timer_id) {

  account.nonce += 1

  const tx = {
    type: 5,  // call
    nonce: account.nonce,
    from: identity.address,
    to: contract_address,
    payload: JSON.stringify({
      "Name": "fire_timer",
      "Args": [timer_id]
    }),
    amount: '0 aer',
    chainIdHash: chainIdHash
  };

  console.log("sending transaction:", tx)

  tx.sign = await crypto.signTransaction(tx, identity.keyPair);
  tx.hash = await crypto.hashTransaction(tx, 'bytes');
  const txhash = await aergo.sendSignedTransaction(tx);
  const txReceipt = await aergo.waitForTransactionReceipt(txhash);

  console.log("transaction receipt:", txReceipt)
}


(async() => {

  // retrieve chain and account info
  chainIdHash = await aergo.getChainIdHash()
  //nonce = await aergo.getNonce(identity.address)
  account = await aergo.getState(identity.address)

  if (account.balance == 0) {
    console.log("--------------------------------------")
    console.log("     Account with zero balance!       ")
    console.log("Insert Aergo tokens on the account and")
    console.log("     then run the script again.       ")
    console.log("--------------------------------------")
    process.exit(1)
  }

  // prepare the database
  db.exec("CREATE TABLE IF NOT EXISTS timers (id INTEGER PRIMARY KEY, fire_time INTEGER)")
  db.exec("CREATE INDEX IF NOT EXISTS timers_fire_time ON timers (fire_time)")

  // get the past events
  await get_past_events()

  // schedule the first call
  schedule_first_call()

  // subscribe to events
  subscribe_to_events()

  // keep record of the "processed" blocks
  update_block_height();

})();


function on_new_timer(timer_id, fire_time) {

  // insert it on the database
  const stmt = db.prepare("INSERT INTO timers VALUES (?,?)")
  stmt.run(timer_id, fire_time)

}

function on_timer_processed(timer_id) {

  // remove it from the database
  db.prepare("DELETE FROM timers WHERE id = ?").run(timer_id)

}

function on_contract_event(event, is_new) {

  console.log(event)

  var timer_id = parseInt(event.args[0])

  switch (event.eventName) {
    case "new_timer":
      var fire_time = parseInt(event.args[1])
      on_new_timer(timer_id, fire_time)
      break
    case "processed":
      on_timer_processed(timer_id)
      break
  }

  if (is_new) {
    schedule_first_call()
  }

}

// retrieve past events from the timer contract
async function get_past_events() {

  const last_block = get_last_block()

  console.log("reading past events... starting at block", last_block)

  const events = await aergo.getEvents({
    address: contract_address,
    blockfrom: last_block
  })

  events.forEach(function(event){
    on_contract_event(event, false)
  })

}

// subscribe to new events from the timer contract
async function subscribe_to_events() {

  console.log("subscribing to new events...")

  const stream = aergo.getEventStream({
    address: contract_address
  })

  stream.on('data', (event) => {
    on_contract_event(event, true)
    //stream.cancel()
  })

}

async function update_block_height() {
  const blockchainState = await aergo.blockchain();
  console.log("current block:", blockchainState.bestHeight);
  fs.writeFileSync(__dirname + '/last_known_block.txt', blockchainState.bestHeight.toString());
  setTimeout(update_block_height, 180 * 1000);  // 3 minutes
}

function get_last_block() {
  try {
    var block_height = fs.readFileSync(__dirname + '/last_known_block.txt').toString();
    return parseInt(block_height)
  } catch (err) {
    return MIN_BLOCK
  }
}

function process_timer() {

  console.log("processing timer", timer.id, "...")

  // call the smart contract
  call_timer(timer.id)

  // remove it from the database
  on_timer_processed(timer.id)

  // schedule the next call
  timeout_id = 0
  schedule_first_call()

}

function schedule_first_call() {

  console.log("scheduling the next call")

  if (timeout_id != 0) {
    clearTimeout(timeout_id)
  }

  // get the first timer to be fired, from the database
  timer = db.prepare("SELECT id, fire_time FROM timers ORDER BY fire_time LIMIT 1").get()
  if (timer) {
    console.log("next timer - id:", timer.id, " fire_time:", timer.fire_time);
  } else {
    return
  }

  // calculate the time to wait from now
  const now = Math.floor(new Date().getTime() / 1000)
  const wait_time = timer.fire_time - now

  if (wait_time > 0) {
    console.log("firing at", wait_time, "seconds from now:", now)
    // create a timeout to execute the next timer
    timeout_id = setTimeout(function() {
      process_timer()
    }, wait_time * 1000)
  } else {
    process_timer()
  }

}

// TODO: sync time with network or blockchain