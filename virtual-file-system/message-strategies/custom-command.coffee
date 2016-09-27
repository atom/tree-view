shell = require 'shell'

module.exports = customCommand = (virtualFileSystem, {payload}) ->
  payload = JSON.parse(payload)

  switch payload.command
    when 'browser_open'
      shell.openExternal(payload.url)
    when 'learn_submit'
      # open atom browser window
    else
      console.log 'Unhandled custom command:', payload.command

