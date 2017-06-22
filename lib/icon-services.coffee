DefaultFileIcons = require './default-file-icons'
{Emitter} = require 'event-kit'

defaultServices =
  'file-icons': new DefaultFileIcons
  'element-icons': null

class IconServices
  constructor: ->
    @emitter = new Emitter()
    @activeServices = Object.assign {}, defaultServices

  get: (name) ->
    @activeServices[name] or defaultServices[name]

  reset: (name) ->
    @set name, defaultServices[name]

  set: (name, service) ->
    if service isnt @activeServices[name]
      @activeServices[name] = service
      @emitter.emit 'did-change'

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

module.exports = new IconServices
