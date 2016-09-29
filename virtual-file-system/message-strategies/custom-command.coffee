shell = require 'shell'

commandStrategies = {
  browser_open: ({url}) ->
    shell.openExternal(url)

  atom_open: ({path}, virtualFileSystem) ->
    node = virtualFileSystem.getNode(path)
    virtualFileSystem.atomHelper.open(node.localPath())

  learn_submit: ({url}) ->
    # open BrowserWindow to url
}

module.exports = customCommand = (virtualFileSystem, {payload}) ->
  try
    data = JSON.parse(payload)
  catch
    return console.error 'Unable to parse customCommand payload:', payload

  {command} = data
  strategy = commandStrategies[command]

  if not strategy?
    console.warn 'No strategy for custom command:', command, data
  else
    strategy(data, virtualFileSystem)

