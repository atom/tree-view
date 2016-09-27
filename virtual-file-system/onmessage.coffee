change = require './message-strategies/change'
customCommand = require './message-strategies/custom-command'
error = require './message-strategies/error'
fetch = require './message-strategies/fetch'
init = require './message-strategies/init'
open = require './message-strategies/open'
sync = require './message-strategies/sync'

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

