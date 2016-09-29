change = require './onmessage-strategies/change'
customCommand = require './onmessage-strategies/custom-command'
error = require './onmessage-strategies/error'
fetch = require './onmessage-strategies/fetch'
init = require './onmessage-strategies/init'
open = require './onmessage-strategies/open'
sync = require './onmessage-strategies/sync'

messageStrategies = {
  change,
  customCommand,
  error,
  fetch,
  init,
  open,
  sync,
}

module.exports = onmessage = (event, virtualFileSystem) ->
  message = event.data

  try
    {type, data} = JSON.parse(message)
    console.log 'RECEIVED:', type
  catch err
    return console.error 'ERROR PARSING MESSAGE:', err

  strategy = messageStrategies[type]

  if not strategy?
    console.error "Unhandled message type: #{type}"
  else
    strategy(virtualFileSystem, data)

