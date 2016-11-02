nsync = require 'nsync-fs'
shell = require 'shell'
atomHelper = require './atom-helper'
WebWindow = require './web-window'

commandStrategies = {
  browser_open: ({url}) ->
    shell.openExternal(url)

  atom_open: ({path}) ->
    node = nsync.getNode(path)
    if node?
      atomHelper.open(node.localPath())

  learn_submit: ({url}) ->
    new WebWindow(url, {resizable: false})
}

module.exports = executeCustomCommand = (data) ->
  console.log 'here in execute!', data
  {command} = data
  strategy = commandStrategies[command]

  if not strategy?
    console.warn 'No strategy for custom command:', command, data
  else
    strategy(data)

