nsync = require 'nsync-fs'
shell = require 'shell'
atomHelper = require './atom-helper'

commandStrategies = {
  browser_open: ({url}) ->
    shell.openExternal(url)

  atom_open: ({path}) ->
    node = nsync.getNode(path)
    atomHelper.open(node.localPath())

  learn_submit: ({url}) ->
    # open BrowserWindow to url
}

module.exports = executeCustomCommand = (data) ->
  console.log 'here in execute!', data
  {command} = data
  strategy = commandStrategies[command]

  if not strategy?
    console.warn 'No strategy for custom command:', command, data
  else
    strategy(data)

