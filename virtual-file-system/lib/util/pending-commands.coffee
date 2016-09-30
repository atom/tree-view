{Emitter} = require 'event-kit'

module.exports =
class PendingCommands
  constructor: ->
    @commands = {}
    @emitter = new Emitter

  onDidAdd: (callback) ->
    @emitter.on('did-add-command', callback)

  onDidRemove: (callback) ->
    @emitter.on('did-remove-command', callback)

  add: (command) ->
    @commands[command] ?= 0
    @commands[command]++
    @emitter.emit('did-add-command', {command})

  remove: (command) ->
    if @commands[command]?
      @commands[command]--
      @emitter.emit('did-remove-command', {command})

  any: (command) ->
    @commands[command]? and @commands[command] > 0

  none: (command) ->
    not @any(command)

  lessThan: (command, limit) ->
    @none(command) or @commands[command] < limit

  greaterThan: (command, limit) ->
    @any(command) and @commands[command] > limit

